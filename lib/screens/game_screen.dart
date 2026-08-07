import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../branding.dart';
import '../logic/coin_rules.dart';
import '../services/analytics_service.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'statistics_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/board_grid.dart';
import 'widgets/board_info_bar.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/cozy_background.dart';
import 'widgets/identity_header.dart';
import 'widgets/keyboard.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/toast.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.startGame(GameMode.daily);
    c.addListener(_onChange);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Roll the daily over live: if the app was open across UTC midnight, reload
    // the new day's puzzle (and its number) on resume instead of showing a
    // stale board.
    if (state == AppLifecycleState.resumed && c.dailyNeedsRefresh) {
      _endShown = false;
      c.startGame(GameMode.daily);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    // The game re-opened (new game or a rewarded extra guess) — allow the
    // end-of-game flow to fire again next time.
    if (!c.gameOver) _endShown = false;

    // Transient messages are owned by the warm ToastHost, which reads and
    // clears c.message itself (replacing the old Material SnackBar).
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
        if (mounted) StatisticsScreen.show(context, c);
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
            CozyBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                drawerScrimColor: AppPalette.drawerScrim,
                drawer: AppDrawer(controller: c),
                body: SafeArea(
                  child: Column(
                    children: [
                      _TopBar(controller: c),
                      const SizedBox(height: 4),
                      ModeSwitcher(mode: c.mode, onChanged: _setMode),
                      IdentityHeader(
                        isJourney: isJourney,
                        dailyNumber: c.dailyNumber,
                        level: c.journeyLevel,
                        chapter: c.journeyChapter,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: BoardGrid(controller: c),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BoardInfoBar(controller: c),
                      _EndActions(
                        controller: c,
                        onNextLevel: _nextJourneyLevel,
                        onRetry: _retryJourneyLevel,
                        onExtraGuess: c.useExtraGuess,
                      ),
                      ToastHost(controller: c),
                      Keyboard(
                        keyStatus: c.keyStatus,
                        onKey: c.onKey,
                        hintedLetters: c.revealedHints.values.toSet(),
                      ),
                    ],
                  ),
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

/// Warm top bar (redesign §4): menu · wordmark · coin pill + hint + stats.
class _TopBar extends StatelessWidget {
  final GameController controller;
  const _TopBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Menu',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Scaffold.of(context).openDrawer(),
                child: _iconBox(const Icon(Icons.menu,
                    size: 20, color: AppPalette.iconStroke)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(Branding.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.fredoka(
                        fontSize: 22,
                        color: AppPalette.ink,
                        letterSpacing: 0.4)),
              ),
            ),
            _CoinPill(controller: c),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.lightbulb_outline,
              tooltip: c.canUseHint
                  ? 'Reveal a letter (costs coins)'
                  : 'Nothing left to reveal',
              onTap: c.canUseHint ? c.useHint : null,
            ),
            const SizedBox(width: 8),
            _IconBtn(
              icon: Icons.bar_chart,
              tooltip: 'Stats',
              onTap: () => StatisticsScreen.show(context, c),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _iconBox(Widget child) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppPalette.chipFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.chipBorder),
        ),
        child: child,
      );
}

/// A 34×34 warm icon button (stats / hint). Dims when disabled.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.chipFill,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppPalette.chipBorder),
          ),
          child: Icon(icon,
              size: 18,
              color: AppPalette.iconStroke
                  .withValues(alpha: enabled ? 1.0 : 0.4)),
        ),
      ),
    );
  }
}

/// Coin balance pill (§4). Tapping opens the watch-ad-to-earn flow.
class _CoinPill extends StatelessWidget {
  final GameController controller;
  const _CoinPill({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.bgGlow,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: controller.watchAdForCoins,
        child: Container(
          height: 34,
          padding: const EdgeInsets.fromLTRB(9, 0, 11, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppPalette.coinPillBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppPalette.coinTop, AppPalette.coinBottom]),
                ),
              ),
              const SizedBox(width: 6),
              Text('${controller.coins}',
                  style: AppType.fredoka(
                      fontSize: 14, color: AppPalette.coinsAmber)),
            ],
          ),
        ),
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
    // Offer a rewarded extra guess on a loss (both modes) — but only when
    // there are guesses to extend.
    if (!c.won && c.guesses.isNotEmpty) {
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
