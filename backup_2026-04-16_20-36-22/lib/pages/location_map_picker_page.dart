import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/location_result.dart';
import '../services/google_places_service.dart';
import '../utils/footer_helper.dart';
import '../utils/ui_constants.dart';
import '../utils/debug_log.dart';

/// Full-Screen Karten-Picker für Location-Auswahl
class LocationMapPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationName;

  const LocationMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationName,
  });

  @override
  State<LocationMapPickerPage> createState() => _LocationMapPickerPageState();
}

class _LocationMapPickerPageState extends State<LocationMapPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String? _selectedAddress;
  String? _selectedPostalCode;
  String? _selectedCity;
  String? _selectedStreet;
  String? _selectedTimezoneId;
  bool _isLoadingLocationData = false;
  bool _locationPermissionGranted = false;
  bool _isRequestingPermission = false;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    // Initialisiere Position: Bei Suche→Karte direkt auf gesuchten Ort (z.B. Marsa Alam),
    // sonst Standard Berlin. Kein automatischer Sprung zu GPS – Nutzer kann Standort-Button nutzen.
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _selectedPosition = const LatLng(52.5200, 13.4050);
    }
    _loadLocationDataForPosition(_selectedPosition!);
    // Beim Öffnen der Karte: Berechtigung prüfen und ggf. anfordern
    _initLocationPermission();
  }

  /// Prüft Standortberechtigung und fordert sie beim Öffnen an (permission_handler).
  Future<void> _initLocationPermission() async {
    final status = await Permission.location.status;
    if (mounted) {
      setState(() {
        _locationPermissionGranted = status.isGranted;
        _locationPermissionDenied = status.isDenied || status.isPermanentlyDenied;
      });
    }
    // Wenn noch nicht entschieden: System-Dialog "Darf die App deinen Standort verwenden?"
    if (status.isDenied || status.isLimited) {
      await _requestLocationPermission();
    }
  }

  /// Fragt die Standortberechtigung an (nur bei expliziter Nutzeraktion)
  Future<void> _requestLocationPermission() async {
    if (_isRequestingPermission) return;

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      final status = await Permission.location.request();
      
      if (mounted) {
        setState(() {
          _locationPermissionGranted = status.isGranted;
          _locationPermissionDenied = status.isDenied || status.isPermanentlyDenied;
          _isRequestingPermission = false;
        });

        if (!status.isGranted) {
          // Zeige Dialog wenn Berechtigung verweigert wurde
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugLog('❌ Fehler bei Standortberechtigung: $e');
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  /// Zeigt Dialog wenn Berechtigung verweigert wurde
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        title: const Text(
          'Standortberechtigung',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Um deinen aktuellen Standort auf der Karte anzuzeigen, benötigen wir deine Standortberechtigung. Du kannst die Position auch manuell auf der Karte auswählen.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: UIConstants.appOrange),
            ),
          ),
        ],
      ),
    );
  }

  /// Wird aufgerufen wenn der Standort-Button geklickt wird
  Future<void> _onMyLocationButtonPressed() async {
    if (!_locationPermissionGranted) {
      // Frage Berechtigung an wenn noch nicht erteilt
      await _requestLocationPermission();
    }
    
    // Wenn Berechtigung jetzt erteilt ist, zentriere Karte auf Standort
    if (_locationPermissionGranted && _mapController != null) {
      // Die Karte wird automatisch auf den Standort zentriert wenn myLocationEnabled = true
      // Wir können hier zusätzlich die Kamera bewegen, falls nötig
    }
  }

  /// Lädt Zeitzone und Adresse (Reverse Geocoding) für die Position.
  /// Bei Fehlern werden alte Adressdaten explizit geleert, damit keine Stale-Daten (z. B. Berlin) hängen bleiben.
  Future<void> _loadLocationDataForPosition(LatLng position) async {
    setState(() {
      _isLoadingLocationData = true;
      _selectedAddress = null;
      _selectedPostalCode = null;
      _selectedCity = null;
      _selectedStreet = null;
    });

    try {
      // Parallel: Timezone + Reverse Geocoding
      final results = await Future.wait([
        GooglePlacesService.getTimezoneIdForCoordinates(
          position.latitude,
          position.longitude,
        ),
        placemarkFromCoordinates(position.latitude, position.longitude)
            .then((list) => list.isNotEmpty ? list.first : null),
      ]);

      final timezoneId = results[0] as String?;
      final placemark = results[1] as Placemark?;

      String? address;
      String? postalCode;
      String? city;
      String? street;

      if (placemark != null) {
        postalCode = placemark.postalCode?.trim().isNotEmpty == true
            ? placemark.postalCode?.trim()
            : null;
        city = placemark.locality?.trim().isNotEmpty == true
            ? placemark.locality?.trim()
            : null;
        final thoroughfare = placemark.thoroughfare?.trim() ?? '';
        final subThoroughfare = placemark.subThoroughfare?.trim() ?? '';
        street = thoroughfare.isNotEmpty || subThoroughfare.isNotEmpty
            ? [thoroughfare, subThoroughfare].join(' ').trim()
            : null;
        final parts = <String>[];
        if (street != null && street!.isNotEmpty) parts.add(street!);
        if (postalCode != null && city != null) {
          parts.add('$postalCode $city');
        } else if (city != null) {
          parts.add(city!);
        }
        if (placemark.country?.trim().isNotEmpty == true) {
          parts.add(placemark.country!.trim());
        }
        address = parts.isNotEmpty ? parts.join(', ') : null;
      }

      if (mounted) {
        setState(() {
          _selectedTimezoneId = timezoneId ?? 'UTC';
          _selectedAddress = address ?? '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _selectedPostalCode = postalCode;
          _selectedCity = city;
          _selectedStreet = street;
          _isLoadingLocationData = false;
        });
      }
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Adresse/Zeitzone: $e');
      if (mounted) {
        setState(() {
          _selectedTimezoneId = 'UTC';
          _selectedAddress = null;
          _selectedPostalCode = null;
          _selectedCity = null;
          _selectedStreet = null;
          _isLoadingLocationData = false;
        });
      }
    }
  }

  void _onMapTap(LatLng position) async {
    setState(() {
      _selectedPosition = position;
    });
    _loadLocationDataForPosition(position);
    
    // Zentriere Karte auf ausgewählte Position
    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(position, 15.0),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    
    // Warte kurz, dann zentriere Karte auf ausgewählter Position
    if (_selectedPosition != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_mapController != null && mounted) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedPosition!, 15.0),
        );
      }
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wähle eine Position auf der Karte aus'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Erstelle LocationResult aus den Koordinaten und Reverse-Geocoding-Daten
    // WICHTIG: Name kommt von der aktuellen Position (Reverse-Geocoding), nicht vom alten Ort
    final coordFallback = '${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}';
    final addr = _selectedAddress ?? coordFallback;
    final hasRealAddress = addr != coordFallback && addr.contains(',');
    final locationName = hasRealAddress ? (_selectedCity ?? _selectedStreet ?? addr) : '';
    final locationResult = LocationResult(
      placeId: 'manual_${_selectedPosition!.latitude}_${_selectedPosition!.longitude}',
      name: locationName,
      address: addr,
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
      timezoneId: _selectedTimezoneId,
      postalCode: _selectedPostalCode,
      city: _selectedCity,
      street: _selectedStreet,
    );

    Navigator.pop(context, locationResult);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UIConstants.djShellPageBackground,
      appBar: AppBar(
        title: const Text('Ort auf Karte wählen'),
        backgroundColor: UIConstants.appBarBackgroundColor,
        foregroundColor: UIConstants.appBarForegroundColor,
        iconTheme: UIConstants.appBarIconTheme,
        titleTextStyle: UIConstants.appBarTitleTextStyle,
      ),
      body: Stack(
        children: [
          // Google Map (Padding unten für Info-Box + Safe Area, damit Karten-Buttons und Google-Schriftzug nicht überlappt werden)
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _selectedPosition ?? const LatLng(52.5200, 13.4050),
              zoom: 15.0,
            ),
            padding: EdgeInsets.only(
              bottom: FooterHelper.getBottomPaddingHeight() + 40.0 + MediaQuery.of(context).padding.bottom,
            ),
            onTap: _onMapTap,
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_location'),
                      position: _selectedPosition!,
                      draggable: true,
                      onDragEnd: (LatLng newPosition) async {
                        setState(() {
                          _selectedPosition = newPosition;
                        });
                        _loadLocationDataForPosition(newPosition);
                        
                        // Zentriere Karte auf neue Position nach Drag
                        if (_mapController != null) {
                          await _mapController!.animateCamera(
                            CameraUpdate.newLatLngZoom(newPosition, 15.0),
                          );
                        }
                      },
                    ),
                  }
                : {},
            mapType: MapType.normal,
            myLocationEnabled: _locationPermissionGranted, // Nur wenn Berechtigung erteilt
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            style: _darkMapStyle,
          ),
          // Info-Box unten (mit Safe-Area-Padding für Geräte mit Home-Indikator)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(
                  top: BorderSide(color: UIConstants.appOrange, width: 2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hinweis wenn Standortberechtigung nicht erteilt wurde
                  if (!_locationPermissionGranted && !_isRequestingPermission)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        border: Border.all(color: UIConstants.appOrange.withValues(alpha: 0.5), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: UIConstants.appOrange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _locationPermissionDenied
                                  ? 'Bitte aktiviere GPS in den Einstellungen, um deinen Standort zu finden.'
                                  : 'Tippe auf den Standort-Button (oben rechts), um deine Position zu verwenden.',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_selectedPosition != null) ...[
                    Text(
                      'Position: ${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (_isLoadingLocationData)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: UIConstants.appOrange,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Adresse und Zeitzone werden ermittelt...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    )
                  else if (_selectedTimezoneId != null) ...[
                    Text(
                      'Zeitzone: $_selectedTimezoneId',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                    if (_selectedAddress != null && _selectedAddress!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Adresse: $_selectedAddress',
                        style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoadingLocationData ? null : _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Position bestätigen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dark Map Style für Google Maps
  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2b2b2b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8a8a8a"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  }
]
''';
}
