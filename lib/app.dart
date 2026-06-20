import 'package:flutter/material.dart';
import 'branding.dart';
import 'screens/game_screen.dart';
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
      home: GameScreen(controller: controller),
    );
  }
}
