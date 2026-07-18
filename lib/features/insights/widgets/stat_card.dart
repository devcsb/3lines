import 'package:flutter/material.dart';

/// 값 문자열의 선행 숫자 추출용 정규식. 카운트업 애니메이션이 매 프레임 값을
/// 파싱하므로 재컴파일을 피하려 상수로 둔다.
final _leadingNumber = RegExp(r'^(\d+\.?\d*)');

/// Stat card with animated count-up effect for numeric values.
class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(StatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.forward(from: 0);
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
    final numericValue = _extractNumber(widget.value);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - _animation.value)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon,
                        size: 18, color: theme.colorScheme.primary),
                  ),
                  const Spacer(),
                  // Animated value
                  numericValue != null
                      ? _AnimatedValue(
                          value: widget.value,
                          numericPart: numericValue,
                          progress: _animation.value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(
                          widget.value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  const SizedBox(height: 2),
                  Text(
                    widget.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Extract leading numeric portion from value string (e.g. "42일" → 42.0)
  static double? _extractNumber(String value) {
    final match = _leadingNumber.firstMatch(value);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }
}

/// Renders an animated count-up for the numeric part, preserving any suffix.
class _AnimatedValue extends StatelessWidget {
  final String value;
  final double numericPart;
  final double progress;
  final TextStyle? style;

  const _AnimatedValue({
    required this.value,
    required this.numericPart,
    required this.progress,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final current = numericPart * progress;
    final numStr = _leadingNumber.firstMatch(value)!.group(0)!;
    final suffix = value.substring(numStr.length);

    // Preserve decimal format from original
    final formatted = numStr.contains('.')
        ? current.toStringAsFixed(1)
        : current.round().toString();

    return Text('$formatted$suffix', style: style);
  }
}
