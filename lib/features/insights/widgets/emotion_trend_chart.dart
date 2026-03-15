import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class EmotionTrendChart extends StatelessWidget {
  final List<({DateTime date, int emotion})> data;

  const EmotionTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('데이터가 없어요',
              style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final totalDays = lastDate.difference(firstDate).inDays;

    // Build a map from day-offset to data for tooltips
    final dataByOffset = <int, ({DateTime date, int emotion})>{};
    for (final d in data) {
      final offset = d.date.difference(firstDate).inDays;
      dataByOffset[offset] = d;
    }

    // Split data into consecutive-day segments for gap handling
    // PRD 4.4: "기록 없는 날은 빈 구간 (선 끊김)"
    final segments = <List<FlSpot>>[];
    List<FlSpot> currentSegment = [];

    for (int i = 0; i < data.length; i++) {
      final dayOffset = data[i].date.difference(firstDate).inDays.toDouble();
      final spot = FlSpot(dayOffset, data[i].emotion.toDouble());

      if (i > 0) {
        final prevDate = data[i - 1].date;
        final gap = data[i].date.difference(prevDate).inDays;
        if (gap > 1) {
          // Gap detected — start a new segment
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
          }
          currentSegment = [spot];
          continue;
        }
      }
      currentSegment.add(spot);
    }
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    // Create one LineChartBarData per segment
    final lineBars = segments.map((spots) {
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        color: theme.colorScheme.primary,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) {
            final emotion = spot.y.toInt();
            return FlDotCirclePainter(
              radius: 4,
              color: AppColors.emotionColors[emotion] ??
                  theme.colorScheme.primary,
              strokeWidth: 0,
            );
          },
        ),
        belowBarData: BarAreaData(
          show: true,
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
      );
    }).toList();

    // Bottom title interval based on total day span
    final bottomInterval = totalDays > 14
        ? (totalDays / 4).ceilToDouble()
        : totalDays > 0
            ? 1.0
            : 1.0;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: totalDays.toDouble(),
          minY: 0.5,
          maxY: 5.5,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, _) {
                  if (value < 1 || value > 5) return const SizedBox();
                  return Text(
                    AppColors.emotionEmojis[value.toInt()] ?? '',
                    style: const TextStyle(fontSize: 14),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: bottomInterval,
                getTitlesWidget: (value, _) {
                  final dayOffset = value.toInt();
                  if (dayOffset < 0 || dayOffset > totalDays) {
                    return const SizedBox();
                  }
                  final date = firstDate.add(Duration(days: dayOffset));
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: lineBars,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final dayOffset = spot.x.toInt();
                  final entry = dataByOffset[dayOffset];
                  if (entry == null) return null;
                  final emoji =
                      AppColors.emotionEmojis[entry.emotion] ?? '';
                  return LineTooltipItem(
                    '$emoji ${entry.date.month}/${entry.date.day}',
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
