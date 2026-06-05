import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Größen für Kreisdiagramme auf der DJ-Startseite (Handy/Tablet, Hoch/Quer).
class StatsPieChartMetrics {
  const StatsPieChartMetrics({
    required this.diameter,
    required this.sectionRadius,
    required this.centerSpaceRadius,
    required this.titleFontSize,
  });

  final double diameter;
  final double sectionRadius;
  final double centerSpaceRadius;
  final double titleFontSize;

  /// Passt Durchmesser an Viewport an — soll ohne Scrollen sichtbar bleiben.
  static StatsPieChartMetrics resolve(
    BuildContext context, {
    double? maxLayoutWidth,
  }) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final padding = media.padding;
    final viewH = size.height - padding.top - padding.bottom;
    final viewW = size.width - padding.left - padding.right;
    final shortest = size.shortestSide;
    final isTablet = shortest >= 600;
    final landscape = size.width > size.height;

    final heightFactor = isTablet ? (landscape ? 0.28 : 0.24) : 0.22;
    final widthFactor = isTablet ? (landscape ? 0.24 : 0.38) : 0.50;

    var diameter = math.min(viewH * heightFactor, viewW * widthFactor);

    if (maxLayoutWidth != null && maxLayoutWidth.isFinite && maxLayoutWidth > 0) {
      diameter = math.min(diameter, maxLayoutWidth * 0.58);
    }

    final maxD = isTablet ? (landscape ? 360.0 : 300.0) : 240.0;
    diameter = diameter.clamp(132.0, maxD);

    return StatsPieChartMetrics(
      diameter: diameter,
      sectionRadius: diameter * 0.30,
      centerSpaceRadius: diameter * 0.20,
      titleFontSize: (diameter * 0.055).clamp(10.0, 13.0),
    );
  }
}

/// Leerzustand: weißer Kreis in exakt derselben Größe wie das Diagramm.
class StatsPieChartEmptyCircle extends StatelessWidget {
  const StatsPieChartEmptyCircle({super.key, required this.metrics});

  final StatsPieChartMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: metrics.diameter,
      height: metrics.diameter,
      child: Center(
        child: Container(
          width: metrics.diameter,
          height: metrics.diameter,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Kreisdiagramm + Legende in einer Zeile (feste Kreisgröße).
class StatsPieChartLegendRow extends StatelessWidget {
  const StatsPieChartLegendRow({
    super.key,
    required this.metrics,
    required this.pie,
    required this.legend,
  });

  final StatsPieChartMetrics metrics;
  final Widget pie;
  final Widget legend;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: metrics.diameter,
          height: metrics.diameter,
          child: pie,
        ),
        const SizedBox(width: 16),
        Expanded(child: legend),
      ],
    );
  }
}

/// Ein Segment im Kreisdiagramm.
class StatsPieChartSlice {
  const StatsPieChartSlice({
    required this.value,
    required this.title,
    required this.color,
  });

  final double value;
  final String title;
  final Color color;
}

/// Baut [PieChart] mit skalierten Radien.
Widget buildStatsPieChart({
  required StatsPieChartMetrics metrics,
  required List<StatsPieChartSlice> sections,
}) {
  return PieChart(
    PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: metrics.centerSpaceRadius,
      startDegreeOffset: 270,
      sections: sections
          .map(
            (s) => PieChartSectionData(
              value: s.value,
              title: s.title,
              color: s.color,
              radius: metrics.sectionRadius,
              titleStyle: TextStyle(
                fontSize: metrics.titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
          .toList(),
    ),
  );
}

/// Percent-Label für Sektionen.
String statsPiePercentLabel(int part, int total) {
  if (total <= 0) return '0%';
  return '${(part / total * 100).toStringAsFixed(1)}%';
}
