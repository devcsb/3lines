import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_utils.dart' as du;

class HeatmapGrid extends StatefulWidget {
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
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void didUpdateWidget(HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-trigger animation when data changes (period switch)
    if (oldWidget.emotionMap != widget.emotionMap ||
        oldWidget.startDate != widget.startDate) {
      _waveController
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final now = DateTime.now();
    const dayLabels = ['월', '', '수', '', '금', '', ''];

    final startMonday = widget.startDate
        .subtract(Duration(days: widget.startDate.weekday - 1));
    final endMonday = now.subtract(Duration(days: now.weekday - 1));
    final weeks = (endMonday.difference(startMonday).inDays ~/ 7) + 1;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final availableWidth = screenWidth - 32 - 30;
    final cellSize = (availableWidth / weeks).clamp(8.0, 20.0);
    const gap = 2.0;
    final tapSize = cellSize + gap;

    // 셀 그리드는 웨이브 애니메이션 프레임마다 불변이므로 AnimatedBuilder 밖에서
    // 한 번만 만든다. 프레임마다 바뀌는 건 주(week)별 Opacity/Transform.scale 뿐이라,
    // 미리 만든 컬럼을 자식으로 넘기면 셀(_HeatmapCell) 재빌드가 매 프레임 안 돈다.
    final weekColumns = List.generate(weeks, (weekIndex) {
      final weekStart = _getWeekStart(now, weeks - 1 - weekIndex);
      return Column(
        children: List.generate(7, (dayIndex) {
          final date = weekStart.add(Duration(days: dayIndex));
          if (date.isAfter(now) || date.isBefore(widget.startDate)) {
            return SizedBox(width: tapSize, height: tapSize);
          }
          final dateStr = du.dateToString(date);
          final emotion = widget.emotionMap[dateStr];
          final tooltipMsg = emotion != null
              ? '${date.month}/${date.day} ${AppColors.emotionLabels[emotion]} $emotion점'
              : '${date.month}/${date.day} 기록 없음';

          return _HeatmapCell(
            tapSize: tapSize,
            cellSize: cellSize,
            color: AppColors.getHeatmapColor(emotion, brightness),
            tooltipMsg: tooltipMsg,
            semanticLabel:
                '${du.formatKoreanDate(date)}, ${emotion != null ? "감정 $emotion점" : "기록 없음"}',
            onTap: emotion != null
                ? () => widget.onCellTap?.call(dateStr)
                : null,
          );
        }),
      );
    });

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
              // Grid with staggered wave animation.
              // SingleChildScrollView 는 AnimatedBuilder 밖에 둬서 매 프레임
              // 재생성되지 않게 하고, 빌더는 주별 Opacity/Transform 만 갱신한다.
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, _) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(weeks, (weekIndex) {
                          // Stagger: most recent weeks animate first
                          final reversedIndex = weeks - 1 - weekIndex;
                          final start =
                              (reversedIndex / weeks * 0.65).clamp(0.0, 1.0);
                          final end = (start + 0.35).clamp(0.0, 1.0);
                          // Use Interval.transform directly to avoid
                          // allocating a CurvedAnimation object per frame.
                          final interval =
                              Interval(start, end, curve: Curves.easeOutCubic);
                          final progress =
                              interval.transform(_waveController.value);

                          return Opacity(
                            opacity: progress.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * progress,
                              alignment: Alignment.center,
                              child: weekColumns[weekIndex],
                            ),
                          );
                        }),
                      );
                    },
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
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: AppColors.getHeatmapColor(null, brightness),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
    final weekday = date.weekday;
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
            ? (_) {
                if (mounted) setState(() => _highlighted = true);
              }
            : null,
        onTapUp: widget.onTap != null
            ? (_) {
                HapticService.light();
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
                    borderRadius: BorderRadius.circular(3),
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
