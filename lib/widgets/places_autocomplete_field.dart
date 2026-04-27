import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/location_result.dart';
import '../services/google_places_service.dart';
import '../utils/ui_constants.dart';

/// Autocomplete-Feld für Google Places mit dunklem Design
class PlacesAutocompleteField extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<LocationResult?>? onPlaceSelected;
  final String? Function(String?)? validator;
  final bool enabled;

  const PlacesAutocompleteField({
    super.key,
    this.initialValue,
    this.onPlaceSelected,
    this.validator,
    this.enabled = true,
  });

  @override
  State<PlacesAutocompleteField> createState() => _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Verzögertes Entfernen, damit Tap-Events durchkommen
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _removeOverlay();
        }
      });
    }
  }

  Future<void> _onTextChanged(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final predictions = await GooglePlacesService.searchAutocomplete(value);

    if (!mounted) return;

    setState(() {
      _predictions = predictions;
      _isLoading = false;
      _showSuggestions = predictions.isNotEmpty && _focusNode.hasFocus;
    });

    if (_showSuggestions) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  Future<void> _onPlaceSelected(PlacePrediction prediction) async {
    _controller.text = prediction.description;
    _focusNode.unfocus();
    
    setState(() {
      _showSuggestions = false;
      _isLoading = true;
    });
    _removeOverlay();

    // Place-Details abrufen
    final locationResult = await GooglePlacesService.getPlaceDetails(prediction.placeId);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (locationResult != null) {
      widget.onPlaceSelected?.call(locationResult);
    }
  }

  void _showOverlay() {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32, // Abzug für Padding
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56), // Unterhalb des Eingabefelds
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return InkWell(
                    onTap: () => _onPlaceSelected(prediction),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade800,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: UIConstants.appOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prediction.mainText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (prediction.secondaryText != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    prediction.secondaryText!,
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Location suchen',
          hintText: 'z.B. Marsa Alam, Club XYZ, Wüste, Strand',
          hintStyle: TextStyle(color: Colors.grey.shade600),
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: UIConstants.appOrange,
                    ),
                  ),
                )
              : const Icon(Icons.add_location, color: UIConstants.appOrange),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _controller.clear();
                    widget.onPlaceSelected?.call(null);
                    setState(() {
                      _predictions = [];
                      _showSuggestions = false;
                    });
                    _removeOverlay();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.black,
        ),
        onChanged: _onTextChanged,
        validator: widget.validator,
      ),
    );
  }
}
