import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/settings/settings_keys.dart';
import '../../core/services/haptic_service.dart';
import '../../core/theme/app_motion.dart';
import '../../data/repositories/settings_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    (
      icon: Icons.edit_rounded,
      title: '하루 3줄로\n기록해요',
      subtitle: '감정 하나와 답변 한 개부터 저장할 수 있어요',
      accentColor: Color(0xFF5B8A6A),
    ),
    (
      icon: Icons.auto_graph_rounded,
      title: '감정을\n돌아봐요',
      subtitle: '기록한 날의 감정을 히트맵과 통계로 돌아봐요',
      accentColor: Color(0xFF6B8A8A),
    ),
    (
      icon: Icons.shield_rounded,
      title: '기록을\n보관해요',
      subtitle: '자체 서버로 기록을 전송하지 않아요. 앱 삭제나 기기 분실에 대비해 텍스트 기록을 내보내세요',
      accentColor: Color(0xFF8A7E6B),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    HapticService.medium();
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSetting(SettingKeys.onboardingDone, 'true');
    ref.invalidate(onboardingDoneProvider);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;
    final reduceMotion = AppMotion.reduceMotion(context);
    final motionDuration = AppMotion.durationFor(context, AppMotion.standard);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: !isLastPage
                  ? TextButton(
                      onPressed: _completeOnboarding,
                      // semanticsLabel 로 서술 라벨을 주면 버튼 노드 하나가
                      // '온보딩 건너뛰기'로 읽힌다(바깥 Semantics 없이 중복 낭독 방지).
                      child: Text(
                        '건너뛰기',
                        semanticsLabel: '온보딩 건너뛰기',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : const SizedBox(height: 48),
            ),

            // Pages with parallax-style animation
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) {
                  HapticService.selection();
                  setState(() => _currentPage = page);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double value = 1.0;
                      if (!reduceMotion &&
                          _pageController.position.haveDimensions) {
                        value = (_pageController.page ?? 0) - index;
                        value = (1 - value.abs()).clamp(0.0, 1.0);
                      }
                      return _OnboardingPage(
                        icon: page.icon,
                        title: page.title,
                        subtitle: page.subtitle,
                        accentColor: page.accentColor,
                        animationValue: value,
                        theme: theme,
                      );
                    },
                  );
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  Semantics(
                    liveRegion: true,
                    label: '온보딩 ${_currentPage + 1}페이지, 총 ${_pages.length}페이지',
                    excludeSemantics: true,
                    child: Text(
                      '${_currentPage + 1} / ${_pages.length}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Decorative dots supplement the text position.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: motionDuration,
                        curve: AppMotion.standardCurve,
                        width: _currentPage == index ? 24 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated button transition
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: motionDuration,
                      child: isLastPage
                          ? SizedBox(
                              key: const ValueKey('start'),
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _completeOnboarding,
                                child: const Text(
                                  '시작하기',
                                  semanticsLabel: '3Lines 시작하기',
                                ),
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('next'),
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  if (reduceMotion) {
                                    _pageController.jumpToPage(
                                      _currentPage + 1,
                                    );
                                  } else {
                                    _pageController.nextPage(
                                      duration: motionDuration,
                                      curve: AppMotion.standardCurve,
                                    );
                                  }
                                },
                                child: const Text('다음'),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual onboarding page with scale/fade animations driven by scroll.
class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final double animationValue; // 0.0 (off-screen) → 1.0 (centered)
  final ThemeData theme;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.animationValue,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Icon: scale from 0.5 → 1.0
    final iconScale = 0.5 + (animationValue * 0.5);
    // Text: fade and slide up
    final textOpacity = animationValue.clamp(0.0, 1.0);
    final textOffset = (1 - animationValue) * 30;

    return LayoutBuilder(
      builder: (context, constraints) => Semantics(
        label: '$title. $subtitle',
        excludeSemantics: true,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon with double ring
                  Transform.scale(
                    scale: iconScale,
                    child: Opacity(
                      opacity: animationValue.clamp(0.0, 1.0),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.08),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accentColor.withValues(alpha: 0.12),
                            ),
                            child: Icon(
                              icon,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title with slide-up
                  Transform.translate(
                    offset: Offset(0, textOffset),
                    child: Opacity(
                      opacity: textOpacity,
                      child: Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle with delayed slide-up (more offset)
                  Transform.translate(
                    offset: Offset(0, textOffset * 1.3),
                    child: Opacity(
                      opacity: textOpacity,
                      child: Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
