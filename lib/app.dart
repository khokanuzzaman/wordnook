import 'package:flutter/material.dart';
import 'branding.dart';
import 'screens/game_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'state/game_controller.dart';
import 'theme/app_theme.dart';

class WordGameApp extends StatelessWidget {
  final GameController controller;
  const WordGameApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Branding.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _Root(controller: controller),
    );
  }
}

/// Shows the interactive onboarding on first run, then the real game. The
/// onboarding is fully isolated; only when it finishes do we swap in the daily.
class _Root extends StatefulWidget {
  final GameController controller;
  const _Root({required this.controller});

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _showOnboarding = !widget.controller.storage.onboardingSeen;

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingScreen(
        storage: widget.controller.storage,
        onFinish: () => setState(() => _showOnboarding = false),
      );
    }
    return GameScreen(controller: widget.controller);
  }
}
