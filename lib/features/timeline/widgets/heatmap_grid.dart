import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart' as du;

class HeatmapGrid extends StatelessWidget {
  final Map<String, int> emotionMap;
  final DateTime startDate;
  final ValueChanged<String>? onCellTap;

  const HeatmapGrid({
    super.key,
    required this.emotionMap,
    required this.startDate,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final now = DateTime.now();
    const dayLabels = ['', '월', '', '수', '', '금', ''];

    // Calculate weeks - align to Monday boundaries
    final startMonday = startDate.subtract(Duration(days: startDate.weekday - 1));
    final endMonday = now.subtract(Duration(days: now.weekday - 1));
    final weeks = (endMonday.difference(startMonday).inDays ~/ 7) + 1;

    // Cell size calculation
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32 - 30; // padding + day labels
    final cellSize = (availableWidth / weeks).clamp(8.0, 20.0);
    const gap = 2.0;

    // Tap target: use cellSize + gap, but in scrollable grid we don't
    // enforce 44dp minimum (would make the grid too large). The grid is
    // horizontally scrollable so cells can be compact.
    final tapSize = cellSize + gap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tapSize * 7,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              SizedBox(
                width: 30,
                child: Column(
                  children: List.generate(7, (i) {
                    return SizedBox(
                      height: tapSize,
                      child: Center(
                        child: Text(
                          dayLabels[i],
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Grid
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(weeks, (weekIndex) {
                      final weekStart =
                          _getWeekStart(now, weeks - 1 - weekIndex);
                      return Column(
                        children: List.generate(7, (dayIndex) {
                          final date =
                              weekStart.add(Duration(days: dayIndex));
                          if (date.isAfter(now) ||
                              date.isBefore(startDate)) {
                            return SizedBox(
                              width: tapSize,
                              height: tapSize,
                            );
                          }
                          final dateStr = du.dateToString(date);
                          final emotion = emotionMap[dateStr];

                          final tooltipMsg = emotion != null
                              ? '${date.month}/${date.day} ${AppColors.emotionEmojis[emotion]} $emotion점'
                              : '${date.month}/${date.day} 기록 없음';

                          return _HeatmapCell(
                            tapSize: tapSize,
                            cellSize: cellSize,
                            color: AppColors.getHeatmapColor(
                                emotion, brightness),
                            tooltipMsg: tooltipMsg,
                            semanticLabel:
                                '${du.formatKoreanDate(date)}, ${emotion != null ? "감정 $emotion점" : "기록 없음"}',
                            onTap: emotion != null
                                ? () => onCellTap?.call(dateStr)
                                : null,
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('적음 ',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
            // Empty cell
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.getHeatmapColor(null, brightness),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Emotion levels 1-5
            ...List.generate(5, (i) {
              return Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: AppColors.getHeatmapColor(i + 1, brightness),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            Text(' 많음',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  DateTime _getWeekStart(DateTime reference, int weeksAgo) {
    final date = reference.subtract(Duration(days: weeksAgo * 7));
    final weekday = date.weekday; // 1=Monday
    return date.subtract(Duration(days: weekday - 1));
  }
}

/// Individual heatmap cell with tap highlight animation.
class _HeatmapCell extends StatefulWidget {
  final double tapSize;
  final double cellSize;
  final Color color;
  final String tooltipMsg;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _HeatmapCell({
    required this.tapSize,
    required this.cellSize,
    required this.color,
    required this.tooltipMsg,
    required this.semanticLabel,
    this.onTap,
  });

  @override
  State<_HeatmapCell> createState() => _HeatmapCellState();
}

class _HeatmapCellState extends State<_HeatmapCell> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltipMsg,
      waitDuration: const Duration(milliseconds: 300),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap != null
            ? (_) => setState(() => _highlighted = true)
            : null,
        onTapUp: widget.onTap != null
            ? (_) {
                widget.onTap!();
                Future.delayed(const Duration(milliseconds: 250), () {
                  if (mounted) setState(() => _highlighted = false);
                });
              }
            : null,
        onTapCancel: () {
          if (mounted) setState(() => _highlighted = false);
        },
        child: Semantics(
          label: widget.semanticLabel,
          child: SizedBox(
            width: widget.tapSize,
            height: widget.tapSize,
            child: Center(
              child: AnimatedScale(
                scale: _highlighted ? 1.4 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: Container(
                  width: widget.cellSize,
                  height: widget.cellSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                    border: _highlighted
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
