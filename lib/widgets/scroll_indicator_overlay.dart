import 'package:flutter/material.dart';

/// Zentrale Overlay-Logik für Scroll-Indikatoren (oben/unten).
/// Zeigt Pfeile nur dann, wenn in die jeweilige Richtung weiter gescrollt werden kann.
class ScrollIndicatorOverlay extends StatefulWidget {
  const ScrollIndicatorOverlay({
    super.key,
    required this.child,
    this.topOffset = 8,
    this.bottomOffset = 8,
  });

  final Widget child;
  final double topOffset;
  final double bottomOffset;

  @override
  State<ScrollIndicatorOverlay> createState() => _ScrollIndicatorOverlayState();
}

class _ScrollIndicatorOverlayState extends State<ScrollIndicatorOverlay> {
  bool _showTop = false;
  bool _showBottom = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setIndicators(0, 0));
  }

  void _setIndicators(double pixels, double maxScrollExtent) {
    if (!mounted) return;
    final showTop = pixels > 6;
    final showBottom = maxScrollExtent > 6 && pixels < maxScrollExtent - 6;
    if (_showTop == showTop && _showBottom == showBottom) return;
    setState(() {
      _showTop = showTop;
      _showBottom = showBottom;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    _setIndicators(metrics.pixels, metrics.maxScrollExtent);
    return false;
  }

  bool _onMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    _setIndicators(metrics.pixels, metrics.maxScrollExtent);
    return false;
  }

  Widget _buildArrow(IconData icon) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetricsNotification,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: widget.child,
          ),
        ),
        if (_showTop)
          Positioned(
            left: 0,
            right: 0,
            top: widget.topOffset,
            child: _buildArrow(Icons.keyboard_arrow_up_rounded),
          ),
        if (_showBottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomOffset,
            child: _buildArrow(Icons.keyboard_arrow_down_rounded),
          ),
      ],
    );
  }
}

