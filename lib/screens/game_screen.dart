import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../branding.dart';
import '../logic/coin_rules.dart';
import '../services/analytics_service.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'how_to_play_sheet.dart';
import 'settings_screen.dart';
import 'stats_sheet.dart';
import 'widgets/board_grid.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/keyboard.dart';
import 'widgets/mode_switcher.dart';

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
    // A returning player whose daily is already finished should still see the
    // stats sheet — startGame ran before the listener was attached, so handle
    // that initial game-over case explicitly.
    if (c.mode == GameMode.daily && c.gameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleGameOver();
      });
    }
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
      AnalyticsService.instance.logEvent(AnalyticsEvents.onboardingStarted);
      final completed = await HowToPlaySheet.show(context);
      await c.storage.setOnboardingSeen();
      AnalyticsService.instance.logEvent(completed == true
          ? AnalyticsEvents.onboardingCompleted
          : AnalyticsEvents.onboardingSkipped);
    });
  }

  void _onChange() {
    // The game re-opened (new game or a rewarded extra guess) — allow the
    // end-of-game flow to fire again next time.
    if (!c.gameOver) _endShown = false;

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
  bool _celebrate = false;
  void _handleGameOver() {
    if (_endShown) return;
    _endShown = true;
    if (c.won) {
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _celebrate = true);
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

  void _setMode(GameMode mode) {
    if (c.mode == mode) return;
    _endShown = false;
    c.startGame(mode);
    AnalyticsService.instance.logEvent(
      AnalyticsEvents.modeSwitched,
      {AnalyticsParams.to: mode.name},
    );
  }

  void _nextJourneyLevel() {
    _endShown = false;
    c.startGame(GameMode.journey);
  }

  void _retryJourneyLevel() {
    _endShown = false;
    c.retryJourneyLevel();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // Rebuild on game state, coin balance, AND the active board theme.
      listenable:
          Listenable.merge([c, c.coinsListenable, AppPalette.selectedTheme]),
      builder: (context, _) {
        final isJourney = c.mode == GameMode.journey;
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                titleSpacing: 12,
                title: Text(
                  isJourney ? 'Level ${c.journeyLevel}' : Branding.appName,
                ),
                actions: [
                  _CoinChip(controller: c),
                  IconButton(
                    tooltip: c.canUseHint
                        ? 'Reveal a letter (costs coins)'
                        : 'Nothing left to reveal',
                    onPressed: c.canUseHint ? c.useHint : null,
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
                              builder: (_) => SettingsScreen(
                                storage: c.storage,
                                coins: c.coinService,
                              ),
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
                    const SizedBox(height: 8),
                    ModeSwitcher(mode: c.mode, onChanged: _setMode),
                    if (isJourney) _JourneyBanner(controller: c),
                    const SizedBox(height: 8),
                    Expanded(child: BoardGrid(controller: c)),
                    _EndActions(
                      controller: c,
                      onNextLevel: _nextJourneyLevel,
                      onRetry: _retryJourneyLevel,
                      onExtraGuess: c.useExtraGuess,
                    ),
                    Keyboard(controller: c),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (_celebrate)
              Positioned.fill(
                child: CelebrationOverlay(
                  onDone: () {
                    if (mounted) setState(() => _celebrate = false);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// App-bar coin balance. Tapping it opens the watch-ad-to-earn flow.
class _CoinChip extends StatelessWidget {
  final GameController controller;
  const _CoinChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: controller.watchAdForCoins,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    size: 18, color: Color(0xFFF2C24B)),
                const SizedBox(width: 4),
                Text('${controller.coins}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 2),
                const Icon(Icons.add, size: 14, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
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
  final VoidCallback onNextLevel;
  final VoidCallback onRetry;
  final VoidCallback onExtraGuess;
  const _EndActions({
    required this.controller,
    required this.onNextLevel,
    required this.onRetry,
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
          label: const Text('Extra guess (${CoinRules.extraGuessCost} coins)'),
        ),
      );
    }
    if (c.mode == GameMode.journey) {
      buttons.add(
        FilledButton(
          onPressed: c.won ? onNextLevel : onRetry,
          child: Text(c.won ? 'Next level' : 'Try again'),
        ),
      );
    }
    if (buttons.isEmpty) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child:
          Wrap(spacing: 12, alignment: WrapAlignment.center, children: buttons),
    );
  }
}
