import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recipe_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/backend_service.dart';
import '../services/youtube_transcript_service.dart';
import '../theme/app_theme.dart';
import 'recipe_detail_screen.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  final String youtubeUrl;
  const LoadingScreen({super.key, required this.youtubeUrl});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  static const _messages = [
    'Fetching the video…',
    'Reading the transcript…',
    'Analyzing the recipe…',
    'Extracting ingredients…',
    'Building cooking steps…',
    'Polishing the result…',
  ];

  int _messageIndex = 0;
  Timer? _messageTimer;
  Timer? _progressTimer;
  double _progress = 0.05;

  bool _completed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimers();
    _run();
  }

  void _startTimers() {
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() => _messageIndex = (_messageIndex + 1) % _messages.length);
    });
    // Approach but never hit 1.0 until extraction completes.
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted) return;
      setState(() {
        _progress += (0.95 - _progress) * 0.04;
      });
    });
  }

  Future<void> _run() async {
    try {
      final transcriptService = ref.read(transcriptServiceProvider);
      final backend = ref.read(backendServiceProvider);

      final transcript =
          await transcriptService.fetchTranscript(widget.youtubeUrl);
      final recipe = await backend.extractRecipe(
        transcript: transcript,
        youtubeUrl: widget.youtubeUrl,
      );

      await ref.read(recipesProvider.notifier).add(recipe);

      // Persist the lifetime counter increment BEFORE the navigation delay so
      // a crash mid-transition can't lose it. Pro users still increment — the
      // gate only reads the counter when !isPro, so it's harmless.
      await ref.read(extractionCounterProvider.notifier).increment();

      if (!mounted) return;
      _stopTimers();
      setState(() {
        _completed = true;
        _progress = 1.0;
      });
      // Brief pause to show 100%, then push detail screen.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
        ),
      );
    } on TranscriptUnavailableException catch (e) {
      _failWith(e.message);
    } on BackendException catch (e) {
      _failWith(e.message);
    } catch (e) {
      _failWith('Something went wrong: $e');
    }
  }

  void _failWith(String message) {
    if (!mounted) return;
    _stopTimers();
    setState(() => _error = message);
  }

  void _stopTimers() {
    _messageTimer?.cancel();
    _progressTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Extracting recipe'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _error != null ? _buildError() : _buildLoading(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Icon(
            Icons.restaurant_menu,
            color: AppColors.accent,
            size: 44,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(
              begin: 0.95,
              end: 1.05,
              duration: 1300.ms,
              curve: Curves.easeInOut,
            )
            .then()
            .scaleXY(
              begin: 1.05,
              end: 0.95,
              duration: 1300.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            _completed ? 'Done!' : _messages[_messageIndex],
            key: ValueKey(_messageIndex.toString() + _completed.toString()),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'This usually takes about 30–60 seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: _progress,
            backgroundColor: AppColors.surface,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '${(_progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline,
            color: AppColors.error, size: 56),
        const SizedBox(height: 16),
        const Text(
          'We couldn\'t extract this recipe',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _error ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _error = null;
              _progress = 0.05;
              _messageIndex = 0;
            });
            _startTimers();
            _run();
          },
          child: const Text('Try again'),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary),
          child: const Text('Go back'),
        ),
      ],
    );
  }
}
