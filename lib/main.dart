import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/recipe_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to dark mode for the system overlays.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = StorageService();
  await storage.init();

  final subscriptions = SubscriptionService.instance;
  // Don't block the splash on a slow store fetch — SubscriptionService keeps
  // its own state for offerings/isPro and the gate reads it lazily. Failures
  // here are non-fatal: the fallback paywall handles offerings == null.
  unawaited(subscriptions.init());

  final showIntro = !storage.hasSeenOnboarding;

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        subscriptionServiceProvider.overrideWithValue(subscriptions),
      ],
      child: VideoRecipeApp(showIntro: showIntro),
    ),
  );
}

class VideoRecipeApp extends StatelessWidget {
  final bool showIntro;
  const VideoRecipeApp({super.key, required this.showIntro});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Extractor',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      theme: AppTheme.dark(),
      home: showIntro ? const IntroScreen() : const HomeScreen(),
    );
  }
}
