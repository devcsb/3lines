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

    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i].emotion.toDouble()));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
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
                interval: data.length > 7
                    ? (data.length / 4).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox();
                  }
                  final d = data[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${d.month}/${d.day}',
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
          lineBarsData: [
            LineChartBarData(
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
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.spotIndex;
                  if (index >= data.length) return null;
                  final d = data[index];
                  final emoji =
                      AppColors.emotionEmojis[d.emotion] ?? '';
                  return LineTooltipItem(
                    '$emoji ${d.date.month}/${d.date.day}',
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
