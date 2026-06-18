import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../branding.dart';
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
    if (c.won) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    // Daily shows the stats sheet; Journey keeps you in the level flow.
    if (c.mode == GameMode.daily) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) StatsSheet.show(context, c);
      });
    }
  }

  void _toggleMode() {
    _endShown = false;
    c.startGame(
      c.mode == GameMode.daily ? GameMode.journey : GameMode.daily,
    );
  }

  void _restartJourney() {
    _endShown = false;
    c.startGame(GameMode.journey);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final isJourney = c.mode == GameMode.journey;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isJourney
                  ? 'Journey · Level ${c.journeyLevel}'
                  : Branding.appName,
            ),
            actions: [
              TextButton(
                onPressed: _toggleMode,
                child: Text(
                  isJourney ? 'Journey' : 'Daily',
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
            child: Column(
              children: [
                if (isJourney) _JourneyBanner(controller: c),
                const SizedBox(height: 8),
                Expanded(child: BoardGrid(controller: c)),
                _EndActions(
                  controller: c,
                  onNextOrRetry: _restartJourney,
                  onExtraGuess: c.useExtraGuess,
                ),
                Keyboard(controller: c),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Social-proof strip shown above the Journey board.
class _JourneyBanner extends StatelessWidget {
  final GameController controller;
  const _JourneyBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_alt_outlined,
              size: 16, color: Colors.white54),
          const SizedBox(width: 6),
          Text(
            '${controller.journeySolvedPercent}% of players solved this level',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Bottom-of-board actions for end states (Journey next/retry, extra guess).
class _EndActions extends StatelessWidget {
  final GameController controller;
  final VoidCallback onNextOrRetry;
  final VoidCallback onExtraGuess;
  const _EndActions({
    required this.controller,
    required this.onNextOrRetry,
    required this.onExtraGuess,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.gameOver) return const SizedBox(height: 8);

    final buttons = <Widget>[];
    // Offer a rewarded extra guess on a loss (both modes).
    if (!c.won) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onExtraGuess,
          icon: const Icon(Icons.add),
          label: const Text('Extra guess (ad)'),
        ),
      );
    }
    if (c.mode == GameMode.journey) {
      buttons.add(
        FilledButton(
          onPressed: onNextOrRetry,
          child: Text(c.won ? 'Next level' : 'Try again'),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Wrap(spacing: 12, alignment: WrapAlignment.center, children: buttons),
    );
  }
}
