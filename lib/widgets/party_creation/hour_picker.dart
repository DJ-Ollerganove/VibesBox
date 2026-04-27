import 'package:flutter/material.dart';
import '../../utils/ui_constants.dart';

/// Widget für die Auswahl von Stunden und Minuten mit Grid-Layout
/// Unterstützt sowohl Start- als auch Endzeit-Auswahl
class HourPicker extends StatelessWidget {
  final String title;
  final List<int> availableHours;
  final List<int> Function(int? hour) getAvailableMinutes;
  final int? selectedHour;
  final int? selectedMinute;
  final Function(int hour, int minute) onTimeSelected;
  final VoidCallback? onCancel;

  const HourPicker({
    super.key,
    required this.title,
    required this.availableHours,
    required this.getAvailableMinutes,
    this.selectedHour,
    this.selectedMinute,
    required this.onTimeSelected,
    this.onCancel,
  });

  /// Zeigt den HourPicker als Dialog
  static Future<void> show({
    required BuildContext context,
    required String title,
    required List<int> availableHours,
    required List<int> Function(int? hour) getAvailableMinutes,
    int? selectedHour,
    int? selectedMinute,
    required Function(int hour, int minute) onTimeSelected,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            constraints: const BoxConstraints(
              maxHeight: 600,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: HourPicker(
                title: title,
                availableHours: availableHours,
                getAvailableMinutes: getAvailableMinutes,
                selectedHour: selectedHour,
                selectedMinute: selectedMinute,
                onTimeSelected: (hour, minute) {
                  onTimeSelected(hour, minute);
                  Navigator.pop(dialogContext);
                },
                onCancel: () => Navigator.pop(dialogContext),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HourPickerStateful(
      title: title,
      availableHours: availableHours,
      getAvailableMinutes: getAvailableMinutes,
      selectedHour: selectedHour,
      selectedMinute: selectedMinute,
      onTimeSelected: onTimeSelected,
      onCancel: onCancel,
    );
  }
}

class _HourPickerStateful extends StatefulWidget {
  final String title;
  final List<int> availableHours;
  final List<int> Function(int? hour) getAvailableMinutes;
  final int? selectedHour;
  final int? selectedMinute;
  final Function(int hour, int minute) onTimeSelected;
  final VoidCallback? onCancel;

  const _HourPickerStateful({
    required this.title,
    required this.availableHours,
    required this.getAvailableMinutes,
    this.selectedHour,
    this.selectedMinute,
    required this.onTimeSelected,
    this.onCancel,
  });

  @override
  State<_HourPickerStateful> createState() => _HourPickerStatefulState();
}

class _HourPickerStatefulState extends State<_HourPickerStateful> {
  int? _selectedHour;
  bool _showMinutes = false;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.selectedHour;
    _showMinutes = widget.selectedHour != null && widget.selectedMinute == null;
  }

  void _showMinuteSelection() {
    setState(() {
      _showMinutes = true;
    });
  }

  void _goBackToHours() {
    setState(() {
      _showMinutes = false;
    });
  }

  void _selectMinute(int minute) {
    if (_selectedHour != null) {
      widget.onTimeSelected(_selectedHour!, minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showMinutes && _selectedHour != null) {
      // Minutenauswahl anzeigen - Kompakt mit Grid
      final availableMinutes = widget.getAvailableMinutes(_selectedHour);
      return Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment(-1.0, -1.0),
                end: Alignment(1.0, 1.0),
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF121417),
                ],
              ),
              border: Border.all(
                color: UIConstants.appOrange,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: UIConstants.appOrange),
                        onPressed: _goBackToHours,
                      ),
                      Expanded(
                        child: Text(
                          '${widget.title} - Minute wählen',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: availableMinutes.length,
                      itemBuilder: (context, index) {
                        final minute = availableMinutes[index];
                        final isSelected = widget.selectedMinute == minute;
                        return InkWell(
                          onTap: () => _selectMinute(minute),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? UIConstants.appOrange.withValues(alpha: 0.5)
                                  : Colors.grey.shade800,
                              border: Border.all(
                                color: isSelected
                                    ? UIConstants.appOrange
                                    : Colors.grey.shade600,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                minute.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                ).copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: widget.onCancel ?? () => Navigator.pop(context),
                    child: const Text(
                      'Abbrechen',
                      style: TextStyle(color: UIConstants.appOrange),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Stundenauswahl anzeigen - Kompakt mit Grid
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-1.0, -1.0),
              end: Alignment(1.0, 1.0),
              colors: [
                Color(0xFF1F2937),
                Color(0xFF121417),
              ],
            ),
            border: Border.all(
              color: UIConstants.appOrange,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '${widget.title} - Stunde wählen',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: widget.availableHours.length,
                    itemBuilder: (context, index) {
                      final hour = widget.availableHours[index];
                      final isSelected = widget.selectedHour == hour;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedHour = hour;
                            _showMinutes = true;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? UIConstants.appOrange.withValues(alpha: 0.5)
                                : Colors.grey.shade800,
                            border: Border.all(
                              color: isSelected
                                  ? UIConstants.appOrange
                                  : Colors.grey.shade600,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ).copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: widget.onCancel ?? () => Navigator.pop(context),
                  child: const Text(
                    'Abbrechen',
                    style: TextStyle(color: UIConstants.appOrange),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
