import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Keyword cloud with staggered pill entrance animations.
class KeywordCloud extends StatefulWidget {
  final Map<String, int> keywords;

  const KeywordCloud({super.key, required this.keywords});

  @override
  State<KeywordCloud> createState() => _KeywordCloudState();
}

class _KeywordCloudState extends State<KeywordCloud>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _normalDuration(widget.keywords.length),
      vsync: this,
    )..forward();
  }

  Duration _normalDuration(int keywordCount) {
    final milliseconds = (300 + (keywordCount * 60)).clamp(300, 600);
    return Duration(milliseconds: milliseconds);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(KeywordCloud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keywords != widget.keywords) {
      _controller.duration = _normalDuration(widget.keywords.length);
      if (_reduceMotion) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.keywords.isEmpty) {
      return Text(
        '아직 분석할 키워드가 부족해요',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      );
    }

    final maxCount = widget.keywords.values
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    final entries = widget.keywords.entries.toList();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: List.generate(entries.length, (i) {
            final entry = entries[i];
            final intensity = (entry.value / maxCount).clamp(0.3, 1.0);

            // Stagger: each pill starts at a different point in the animation
            final staggerStart = (i / entries.length) * 0.5;
            final pillProgress = ((_controller.value - staggerStart) / 0.5)
                .clamp(0.0, 1.0);
            final easedProgress = AppMotion.standardCurve.transform(
              pillProgress,
            );

            return Opacity(
              opacity: easedProgress,
              child: Transform.scale(
                scale: 0.7 + (0.3 * easedProgress),
                child: Semantics(
                  label: '${entry.key}, ${entry.value}회',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: intensity * 0.4,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      entry.key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12 + (intensity * 3),
                        color: theme.colorScheme.primary.withValues(
                          alpha: intensity,
                        ),
                        fontWeight: intensity > 0.6
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
