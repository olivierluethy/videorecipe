import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_provider.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class _SlideData {
  final IconData icon;
  final String title;
  final String body;
  const _SlideData(
      {required this.icon, required this.title, required this.body});
}

const _slides = <_SlideData>[
  _SlideData(
    icon: Icons.content_paste_go,
    title: 'Paste & Extract',
    body:
        'Paste a YouTube cooking video link and let the app pull out the recipe for you.',
  ),
  _SlideData(
    icon: Icons.menu_book_outlined,
    title: 'Get Your Recipe',
    body:
        'Ingredients, step-by-step instructions, and total cooking time — ready in seconds.',
  ),
  _SlideData(
    icon: Icons.restaurant_menu,
    title: 'Cook with Confidence',
    body:
        'Check off steps as you go, scale servings up or down, and tap any step to jump to that moment in the video.',
  ),
];

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  Future<void> _finish() async {
    await ref.read(storageServiceProvider).setHasSeenOnboarding(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, i) => _Slide(data: _slides[i]),
              ),
            ),
            _Dots(count: _slides.length, current: _page),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _isLast
                    ? SizedBox(
                        key: const ValueKey('get-started'),
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _finish,
                          child: const Text('Get Started'),
                        ),
                      )
                    : Row(
                        key: const ValueKey('skip-next'),
                        children: [
                          TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                            ),
                            child: const Text('Next'),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final _SlideData data;
  const _Slide({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Icon(
              data.icon,
              size: 60,
              color: AppColors.accent,
            ),
          )
              .animate()
              .fadeIn(duration: 350.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 350.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 36),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ).animate().fadeIn(delay: 80.ms, duration: 320.ms),
          const SizedBox(height: 14),
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15.5,
              height: 1.45,
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 320.ms),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;
  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppColors.accent
                : AppColors.textTertiary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
