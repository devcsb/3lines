import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
import '../../core/services/haptic_service.dart';
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
      title: '하루 3줄로\n나를 기록하세요',
      subtitle: '감사, 수용, 의도 — 30초면 충분해요',
      accentColor: Color(0xFF5B8A6A),
    ),
    (
      icon: Icons.auto_graph_rounded,
      title: '감정의 흐름을\n한눈에',
      subtitle: '히트맵과 인사이트로 나를 발견해요',
      accentColor: Color(0xFF6B8A8A),
    ),
    (
      icon: Icons.shield_rounded,
      title: '당신만의\n안전한 공간',
      subtitle: '모든 데이터는 기기에만 저장돼요',
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
    await repo.setSetting('onboarding_done', 'true');
    ref.invalidate(onboardingDoneProvider);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: !isLastPage
                  ? Semantics(
                      button: true,
                      label: '온보딩 건너뛰기',
                      child: TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          '건너뛰기',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                          ),
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
                      if (_pageController.position.haveDimensions) {
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
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
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
                  const SizedBox(height: 32),

                  // Animated button transition
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isLastPage
                          ? Semantics(
                              key: const ValueKey('start'),
                              button: true,
                              label: '3Lines 시작하기',
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _completeOnboarding,
                                  child: const Text('시작하기'),
                                ),
                              ),
                            )
                          : SizedBox(
                              key: const ValueKey('next'),
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration:
                                        const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
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

    return Semantics(
      label: '$title. $subtitle',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with double ring
            Transform.scale(
              scale: iconScale,
              child: Opacity(
                opacity: animationValue.clamp(0.0, 1.0),
                child: Container(
                  width: 104,
                  height: 104,
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
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        icon,
                        size: 32,
                        color: accentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 44),

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
                opacity: (textOpacity - 0.1).clamp(0.0, 1.0),
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
