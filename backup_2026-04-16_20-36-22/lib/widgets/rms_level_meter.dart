import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/shazam_service.dart';
import '../utils/debug_log.dart';

/// 20-Segment LED-Meter für RMS-Pegelanzeige
/// Zeigt nur während aktiver Shazam-Scans (scanning Status)
class RmsLevelMeter extends StatefulWidget {
  const RmsLevelMeter({super.key});

  @override
  State<RmsLevelMeter> createState() => _RmsLevelMeterState();
}

class _RmsLevelMeterState extends State<RmsLevelMeter> {
  static const EventChannel _rmsChannel = EventChannel('dj_og_app/rms_stream');
  final ShazamService _shazamService = ShazamService();
  
  StreamSubscription<double>? _rmsSubscription;
  StreamSubscription<ShazamScanStatus>? _statusSubscription;
  double _currentRms = 0.0;
  bool _isListening = false;
  bool _isScanning = false; // Nur während scanning Status anzeigen

  // RMS-Werte kommen bereits normalisiert (0.0 bis 1.0)
  // Jedes Segment = 5% (0.05)
  static const int _segmentCount = 20;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    if (_isListening) return;
    
    _isListening = true;
    
    // Höre auf Shazam-Status-Änderungen
    _statusSubscription = _shazamService.statusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _isScanning = (status == ShazamScanStatus.scanning);
            // Wenn Scan beendet, sofort auf Null setzen
            if (!_isScanning) {
              _currentRms = 0.0;
            }
          });
        }
      },
    );
    
    // Höre auf RMS-Werte (nur während scanning relevant)
    _rmsSubscription = _rmsChannel.receiveBroadcastStream().cast<double>().listen(
      (rms) {
        if (mounted && _isScanning) {
          setState(() {
            // RMS kommt bereits normalisiert (0.0-1.0)
            // Nur anzeigen wenn Scan aktiv ist
            _currentRms = rms.clamp(0.0, 1.0);
          });
        } else if (mounted && !_isScanning) {
          // Scan nicht aktiv - auf Null setzen
          setState(() {
            _currentRms = 0.0;
          });
        }
      },
      onError: (error) {
        debugLog('RMS Stream Fehler: $error');
        if (mounted) {
          setState(() {
            _currentRms = 0.0;
          });
        }
      },
      cancelOnError: false, // Stream nicht bei Fehler beenden
    );
  }

  void _stopListening() {
    _rmsSubscription?.cancel();
    _rmsSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _isListening = false;
    if (mounted) {
      setState(() {
        _currentRms = 0.0;
        _isScanning = false;
      });
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  /// Berechnet die Anzahl der aktiven Segmente (0-20)
  int _getActiveSegments() {
    // RMS ist bereits normalisiert (0.0-1.0)
    // Konvertiere zu Prozent (0-100%) und dann zu Segmenten (jedes = 5%)
    final percent = (_currentRms * 100).clamp(0.0, 100.0);
    // Jedes Segment = 5%, also Anzahl = percent / 5
    return (percent / 5).ceil().clamp(0, _segmentCount);
  }

  /// Gibt die Farbe für ein Segment zurück
  Color _getSegmentColor(int segmentIndex) {
    final activeSegments = _getActiveSegments();
    
    if (segmentIndex >= activeSegments) {
      // Inaktive Segmente: dunkelgrau
      return Colors.grey[800]!;
    }
    
    // Aktive Segmente: Farben basierend auf Position
    if (segmentIndex < 12) {
      // Segmente 1-12: Grün
      return Colors.green;
    } else if (segmentIndex < 17) {
      // Segmente 13-17: Gelb
      return Colors.yellow[700]!;
    } else {
      // Segmente 18-20: Rot
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final meterWidth = screenWidth * 0.8; // 80% der Bildschirmbreite
    final segmentWidth = (meterWidth - (_segmentCount - 1) * 2) / _segmentCount; // 2px Abstand zwischen Segmenten

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hören:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: meterWidth,
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_segmentCount, (index) {
              return Container(
                width: segmentWidth,
                height: 40,
                margin: EdgeInsets.only(
                  right: index < _segmentCount - 1 ? 2 : 0,
                ),
                decoration: BoxDecoration(
                  color: _getSegmentColor(index),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: _getActiveSegments() > index
                      ? [
                          BoxShadow(
                            color: _getSegmentColor(index).withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

