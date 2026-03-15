import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app.dart';
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
      icon: Icons.edit_note,
      title: '하루 3줄로 나를 기록하세요',
      subtitle: '감사, 수용, 의도 — 30초면 충분해요',
    ),
    (
      icon: Icons.insights,
      title: '감정의 흐름을 한눈에',
      subtitle: '히트맵과 인사이트로 나를 발견해요',
    ),
    (
      icon: Icons.shield,
      title: '당신만의 공간',
      subtitle: '모든 데이터는 기기에만 저장돼요',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (hidden on last page)
            Align(
              alignment: Alignment.topRight,
              child: _currentPage < _pages.length - 1
                  ? TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text('건너뛰기'),
                    )
                  : const SizedBox(height: 48),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) =>
                    setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Semantics(
                    label: '${page.title}. ${page.subtitle}',
                    child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          page.icon,
                          size: 80,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ),

            // Dots + button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == index ? 12 : 8,
                        height: 8,
                        margin:
                            const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: _currentPage == index
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Start button (only on last page)
                  if (_currentPage == _pages.length - 1)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        child: const Text('시작하기'),
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
