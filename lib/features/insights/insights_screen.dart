import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../core/services/haptic_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../../data/repositories/entry_repository.dart';
import '../../shared/widgets/staggered_fade_in.dart';
import 'insights_controller.dart';
import 'widgets/day_of_week_chart.dart';
import 'widgets/emotion_trend_chart.dart';
import 'widgets/gratitude_keywords_list.dart';
import 'widgets/insights_locked_view.dart';
import 'widgets/keyword_cloud.dart';
import 'widgets/monthly_summary_card.dart';
import 'widgets/stat_card.dart';
import 'widgets/weekly_retrospective_card.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(insightsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('데이터를 불러올 수 없어요'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(insightsControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (!state.isUnlocked) {
            return InsightsLockedView(
              totalCount: state.totalCount,
              requiredCount: state.requiredCount,
              onGoToToday: () => context.go('/'),
            );
          }

          return SafeArea(
            child: RefreshIndicator(
            onRefresh: () async {
              HapticService.light();
              ref.invalidate(insightsControllerProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text('인사이트', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 16),

                  // Congratulation banner on first unlock
                  if (state.totalCount == state.requiredCount)
                    _CongratsBanner(requiredCount: state.requiredCount),

                  // Period selector + weekly delta
                  Row(
                    children: [
                      Expanded(child: _PeriodSelector(period: state.period)),
                      if (state.weeklyDelta != null) ...[
                        const SizedBox(width: 12),
                        _WeeklyDeltaBadge(delta: state.weeklyDelta!),
                      ],
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Emotion trend chart
                  StaggeredFadeIn(
                    index: 0,
                    child: _SectionCard(
                      title: '감정 추이',
                      child: EmotionTrendChart(data: state.emotionTrend),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Stats grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.3,
                    children: [
                      StaggeredFadeIn(
                        index: 1,
                        child: StatCard(
                          title: '평균 감정',
                          value: state.averageEmotion.toStringAsFixed(1),
                          icon: Icons.favorite_rounded,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 2,
                        child: StatCard(
                          title: '현재 스트릭',
                          value: '${state.currentStreak}일',
                          icon: Icons.local_fire_department_rounded,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 3,
                        child: StatCard(
                          title: '총 기록',
                          value: '${state.totalCount}개',
                          icon: Icons.description_outlined,
                        ),
                      ),
                      StaggeredFadeIn(
                        index: 4,
                        child: StatCard(
                          title: '최고의 요일',
                          value: state.bestDayOfWeek,
                          icon: Icons.calendar_today_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Day of week chart
                  StaggeredFadeIn(
                    index: 5,
                    child: _SectionCard(
                      title: '요일별 감정',
                      child: DayOfWeekChart(data: state.dayOfWeekEmotions),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Keywords
                  StaggeredFadeIn(
                    index: 6,
                    child: _SectionCard(
                      title: '자주 쓴 키워드',
                      child: KeywordCloud(keywords: state.keywords),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Gratitude keywords
                  StaggeredFadeIn(
                    index: 7,
                    child: _SectionCard(
                      title: '감사 키워드 TOP 5',
                      child: GratitudeKeywordsList(
                          keywords: state.gratitudeKeywords),
                    ),
                  ),

                  // Monthly summary card
                  if (state.monthlySummary != null) ...[
                    const SizedBox(height: 16),
                    StaggeredFadeIn(
                      index: 8,
                      child: MonthlySummaryCard(
                          summary: state.monthlySummary!),
                    ),
                  ],

                  // Weekly retrospective
                  if (state.weeklyRetrospective != null) ...[
                    const SizedBox(height: 16),
                    StaggeredFadeIn(
                      index: 9,
                      child: WeeklyRetrospectiveCard(
                          retrospective: state.weeklyRetrospective!),
                    ),
                  ],

                  // Monthly PDF report button
                  const SizedBox(height: 20),
                  StaggeredFadeIn(
                    index: 10,
                    child: _PdfReportButton(
                      monthlySummary: state.monthlySummary,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }
}

/// Wraps a section with a title and consistent card-like container.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          )),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _CongratsBanner extends StatefulWidget {
  const _CongratsBanner({required this.requiredCount});

  final int requiredCount;

  @override
  State<_CongratsBanner> createState() => _CongratsBannerState();
}

class _CongratsBannerState extends State<_CongratsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -20, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    HapticService.medium();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '인사이트가 열렸어요!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.requiredCount}일 기록을 축하해요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.period});

  final InsightsPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: '인사이트 기간 선택',
      child: Row(
        children: [
          _PeriodChip(
            label: '1주',
            selected: period == InsightsPeriod.week1,
            onTap: () => ref
                .read(insightsControllerProvider.notifier)
                .setPeriod(InsightsPeriod.week1),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: '1개월',
            selected: period == InsightsPeriod.month1,
            onTap: () => ref
                .read(insightsControllerProvider.notifier)
                .setPeriod(InsightsPeriod.month1),
          ),
          const SizedBox(width: 8),
          _PeriodChip(
            label: '3개월',
            selected: period == InsightsPeriod.month3,
            onTap: () => ref
                .read(insightsControllerProvider.notifier)
                .setPeriod(InsightsPeriod.month3),
          ),
        ],
      ),
    );
  }
}

/// Custom period chip for a more refined look than ChoiceChip.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () {
        HapticService.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: ts.labelMedium?.copyWith(
            color: selected
                ? cs.onPrimary
                : cs.onSurface.withValues(alpha: 0.6),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Shows week-over-week emotion change as a compact badge.
class _WeeklyDeltaBadge extends StatelessWidget {
  const _WeeklyDeltaBadge({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = delta > 0;
    final isNeutral = delta.abs() < 0.1;

    final color = isNeutral
        ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
        : isPositive
            ? const Color(0xFF5B8A6A)
            : const Color(0xFFC4736A);

    final icon = isNeutral
        ? Icons.remove_rounded
        : isPositive
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    final label = isNeutral
        ? '변화 없음'
        : '${isPositive ? "+" : ""}${delta.toStringAsFixed(1)}';

    return Tooltip(
      message: '지난주 대비 감정 변화',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button to generate and share a monthly PDF report.
class _PdfReportButton extends ConsumerStatefulWidget {
  const _PdfReportButton({required this.monthlySummary});

  final MonthlySummary? monthlySummary;

  @override
  ConsumerState<_PdfReportButton> createState() => _PdfReportButtonState();
}

class _PdfReportButtonState extends ConsumerState<_PdfReportButton> {
  bool _generating = false;

  Future<void> _generateReport() async {
    if (_generating) return;
    setState(() => _generating = true);

    try {
      final now = DateTime.now();
      final repo = ref.read(entryRepositoryProvider);
      final entries = await repo.getMonthlyEntries(now.year, now.month);

      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이번 달 기록이 없어요')),
          );
        }
        return;
      }

      final summary = widget.monthlySummary;
      final service = PdfReportService();
      final pdfBytes = await service.generateMonthlyReport(
        year: now.year,
        month: now.month,
        entries: entries,
        averageEmotion: summary?.averageEmotion ?? 0.0,
        topKeyword: summary?.topKeyword ?? '',
      );

      if (!mounted) return;

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'three_lines_${now.year}_${now.month.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF 생성 중 오류가 발생했어요: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: _generating ? null : _generateReport,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_generating)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.picture_as_pdf_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(width: 8),
            Text(
              _generating ? '리포트 생성 중...' : '월간 리포트 PDF',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
