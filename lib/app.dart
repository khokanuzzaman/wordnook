import 'package:flutter/material.dart';
import 'screens/game_screen.dart';
import 'state/game_controller.dart';
import 'theme/app_theme.dart';

class WordGameApp extends StatelessWidget {
  final GameController controller;
  const WordGameApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // TODO: your own brand name (NOT "Wordle").
      title: 'Daily Word',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: GameScreen(controller: controller),
    );
  }
}
