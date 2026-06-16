import 'package:flutter/material.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'stats_sheet.dart';
import 'widgets/board_grid.dart';
import 'widgets/keyboard.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.startGame(GameMode.daily);
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final msg = c.message;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
      c.clearMessage();
    }
    if (c.gameOver && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeShowEnd();
      });
    }
  }

  bool _endShown = false;
  void _maybeShowEnd() {
    if (_endShown) return;
    _endShown = true;
    StatsSheet.show(context, c);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // TODO: replace with your brand name (NOT "Wordle").
        title: const Text('Daily Word'),
        actions: [
          TextButton(
            onPressed: () {
              _endShown = false;
              c.startGame(
                c.mode == GameMode.daily ? GameMode.practice : GameMode.daily,
              );
            },
            child: Text(
              c.mode == GameMode.daily ? 'Daily' : 'Practice',
              style: const TextStyle(
                color: AppPalette.correct,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Hint (watch ad)',
            onPressed: c.gameOver ? null : c.useHint,
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Stats',
            onPressed: () => StatsSheet.show(context, c),
            icon: const Icon(Icons.bar_chart),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Expanded(child: BoardGrid(controller: c)),
                if (c.gameOver && !c.won && c.mode == GameMode.practice)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: FilledButton(
                      onPressed: () {
                        _endShown = false;
                        c.startGame(GameMode.practice);
                      },
                      child: const Text('Next word'),
                    ),
                  ),
                Keyboard(controller: c),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}
