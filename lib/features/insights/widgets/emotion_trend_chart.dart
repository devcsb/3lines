import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

class EmotionTrendChart extends StatefulWidget {
  final List<({DateTime date, int emotion})> data;

  const EmotionTrendChart({super.key, required this.data});

  @override
  State<EmotionTrendChart> createState() => _EmotionTrendChartState();
}

class _EmotionTrendChartState extends State<EmotionTrendChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _drawController;
  late Animation<double> _drawAnimation;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      duration: AppMotion.entrance,
      vsync: this,
    );
    _drawAnimation = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeOutCubic,
    );
    _drawController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion) {
      _drawController.stop();
      _drawController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(EmotionTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      if (_reduceMotion) {
        _drawController.value = 1.0;
      } else {
        _drawController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _drawController.dispose();
    super.dispose();
  }

  List<({DateTime date, int emotion})> get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (data.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text('데이터가 없어요', style: theme.textTheme.bodyMedium),
        ),
      );
    }

    final firstDate = data.first.date;
    final lastDate = data.last.date;
    final totalDays = lastDate.difference(firstDate).inDays;

    // Single data point: expand range so the chart renders properly
    if (totalDays == 0) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: MediaQuery.textScalerOf(context).scale(48),
                height: MediaQuery.textScalerOf(context).scale(48),
                decoration: BoxDecoration(
                  color:
                      AppColors.emotionColors[data.first.emotion]?.withValues(
                        alpha: 0.2,
                      ) ??
                      theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${data.first.emotion}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${AppColors.emotionLabels[data.first.emotion]} · ${firstDate.month}/${firstDate.day}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
          getDotPainter: (spot, _, _, _) {
            final emotion = spot.y.toInt();
            return FlDotCirclePainter(
              radius: 4,
              color:
                  AppColors.emotionColors[emotion] ?? theme.colorScheme.primary,
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

    // FadeTransition 은 자식(LineChart)을 재빌드하지 않고 레이어 알파만 갱신한다.
    // 기존 AnimatedBuilder+Opacity 는 페이드 1초 동안 매 프레임 차트 전체를
    // 재구성(fl_chart painter 재계산)해 낭비였다.
    return FadeTransition(
      opacity: _drawAnimation,
      child: SizedBox(
        height: 200,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final leftReservedSize = scaler.scale(12) * 2.5 + 8;
            final plotWidth = (constraints.maxWidth - leftReservedSize)
                .clamp(1.0, double.infinity)
                .toDouble();
            final painter = TextPainter(
              textDirection: Directionality.of(context),
              textScaler: scaler,
            );
            var maxDateWidth = 0.0;
            // Insights periods cap this scan at three months; wider ranges should
            // measure representative month/day labels instead of every day.
            for (var offset = 0; offset <= totalDays; offset++) {
              final date = firstDate.add(Duration(days: offset));
              painter.text = TextSpan(
                text: '${date.month}/${date.day}',
                style: theme.textTheme.bodySmall,
              );
              painter.layout();
              if (painter.width > maxDateWidth) maxDateWidth = painter.width;
            }
            painter.dispose();
            // fitInside moves endpoint labels inward by half their width.
            final minimumTickSpace = maxDateWidth * 1.5 + 8;
            final bottomInterval = (totalDays * minimumTickSpace / plotWidth)
                .ceil()
                .clamp(1, totalDays)
                .toDouble();
            return LineChart(
              LineChartData(
                minX: 0,
                maxX: totalDays.toDouble(),
                minY: 0.5,
                maxY: 5.5,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: leftReservedSize,
                      interval: 1,
                      getTitlesWidget: (value, _) {
                        if (value < 1 || value > 5) return const SizedBox();
                        return Text(
                          AppColors.emotionLabels[value.toInt()] ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize:
                          MediaQuery.textScalerOf(context).scale(12) * 1.5 + 8,
                      interval: bottomInterval,
                      getTitlesWidget: (value, meta) {
                        final dayOffset = value.toInt();
                        if (dayOffset < 0 || dayOffset > totalDays) {
                          return const SizedBox();
                        }
                        if (dayOffset > 0 &&
                            dayOffset < totalDays &&
                            ((totalDays - dayOffset) * plotWidth / totalDays <
                                    minimumTickSpace ||
                                dayOffset * plotWidth / totalDays <
                                    minimumTickSpace)) {
                          return const SizedBox();
                        }
                        final date = firstDate.add(Duration(days: dayOffset));
                        return SideTitleWidget(
                          meta: meta,
                          space: 4,
                          fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                          child: Text(
                            '${date.month}/${date.day}',
                            style: theme.textTheme.bodySmall,
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
                    getTooltipColor: (_) =>
                        theme.colorScheme.surfaceContainerHighest,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final dayOffset = spot.x.toInt();
                        final entry = dataByOffset[dayOffset];
                        if (entry == null) return null;
                        final label =
                            AppColors.emotionLabels[entry.emotion] ?? '';
                        return LineTooltipItem(
                          '$label ${entry.date.month}/${entry.date.day}',
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
            );
          },
        ),
      ),
    );
  }
}
