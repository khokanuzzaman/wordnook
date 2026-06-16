import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'how_to_play_sheet.dart';
import 'settings_screen.dart';
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
    _maybeOnboard();
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    super.dispose();
  }

  /// Show the how-to-play sheet once, on first ever launch.
  void _maybeOnboard() {
    if (c.storage.onboardingSeen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await HowToPlaySheet.show(context);
      await c.storage.setOnboardingSeen();
    });
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
        if (mounted) _handleGameOver();
      });
    }
  }

  bool _endShown = false;
  void _handleGameOver() {
    if (_endShown) return;
    _endShown = true;
    // Reveal flip runs first; let it finish before the haptic + stats sheet.
    if (c.won) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) StatsSheet.show(context, c);
    });
  }

  void _toggleMode() {
    _endShown = false;
    c.startGame(
      c.mode == GameMode.daily ? GameMode.practice : GameMode.daily,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Word'),
        actions: [
          TextButton(
            onPressed: _toggleMode,
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'how':
                  HowToPlaySheet.show(context);
                case 'settings':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(storage: c.storage),
                    ),
                  );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'how', child: Text('How to play')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
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
