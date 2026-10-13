import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../branding.dart';
import '../logic/coin_rules.dart';
import '../logic/countdown.dart';
import '../logic/tips.dart';
import '../services/analytics_service.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'statistics_screen.dart';
import 'widgets/app_drawer.dart';
import 'widgets/board_grid.dart';
import 'widgets/board_info_bar.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/daily_ready_sheet.dart';
import 'widgets/cozy_background.dart';
import 'widgets/identity_header.dart';
import 'widgets/keyboard.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/share_action.dart';
import 'widgets/toast.dart';

class GameScreen extends StatefulWidget {
  final GameController controller;
  const GameScreen({super.key, required this.controller});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController get c => widget.controller;

  // Runs the one-time "Not sure? Try STARE" tip after an idle empty board.
  Timer? _idleTip;
  bool _drawerOpen = false;

  // Fires just after local midnight so an open app moves to the new Daily.
  Timer? _midnight;

  void _armMidnight() {
    _midnight?.cancel();
    _midnight = Timer(
        timeUntilNextDaily() + const Duration(seconds: 1), _onMidnight);
  }

  void _onMidnight() {
    if (!mounted) return;
    // Roll over only when nothing is in progress — never wipe a half-played
    // board. A mid-game player keeps it until they finish or resume the app.
    final idle = c.gameOver || (c.guesses.isEmpty && c.current.isEmpty);
    if (c.dailyNeedsRefresh && idle) {
      _endShown = false;
      c.startGame(GameMode.daily);
    }
    _armMidnight();
  }

  void _armIdleTip() {
    _idleTip?.cancel();
    _idleTip = null;
    if (!c.idleTipEligible || _drawerOpen) return;
    _idleTip = Timer(TipRules.idleDelay, () {
      // Only if the board is actually on screen (no drawer, sheet or route on
      // top) — otherwise the tip would be "seen" by nobody.
      if (mounted &&
          !_drawerOpen &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        c.showIdleTip();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A brand-new player starts on the warm-up Journey levels; everyone else
    // opens on the Daily.
    c.startGame(c.inFirstSteps ? GameMode.journey : GameMode.daily);
    c.addListener(_onChange);
    _armIdleTip();
    _armMidnight();
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
    // The idle-tip clock only runs while the app is in the foreground.
    if (state == AppLifecycleState.resumed) {
      _armIdleTip();
      _armMidnight();
    } else {
      _idleTip?.cancel();
      _idleTip = null;
    }
    // Roll the daily over live: if the app was open across midnight, reload
    // the new day's puzzle (and its number) on resume instead of showing a
    // stale board.
    if (state == AppLifecycleState.resumed && c.dailyNeedsRefresh) {
      _endShown = false;
      c.startGame(GameMode.daily);
    }
  }

  @override
  void dispose() {
    _idleTip?.cancel();
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    // Any activity restarts (or cancels) the idle-tip clock.
    _armIdleTip();
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
    } else if (c.takeDailyReadyPending()) {
      // Last warm-up cleared: point the new player at today's Daily, once —
      // unless they already moved on (Next level / Daily tab) in the delay.
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted &&
            c.mode == GameMode.journey &&
            c.gameOver &&
            c.won) {
          _showDailyReady();
        }
      });
    }
  }

  Future<void> _showDailyReady() async {
    final goDaily = await DailyReadySheet.show(context);
    if (goDaily == true && mounted) _setMode(GameMode.daily);
  }

  void _setMode(GameMode mode) {
    if (c.mode == mode) return;
    // Leaving the warm-up early for the Daily ends First Steps quietly.
    if (mode == GameMode.daily && c.inFirstSteps) {
      c.endFirstSteps(AnalyticsFirstStepsEnd.switchedToDaily);
    }
    _endShown = false;
    c.startGame(mode);
    AnalyticsService.instance.logEvent(
      AnalyticsEvents.modeSwitched,
      {AnalyticsParams.to: mode.name},
    );
  }

  void _nextJourneyLevel() {
    _endShown = false;
    c.nextJourneyLevel();
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
        // Short phones (e.g. 360×640): trim chrome so the board keeps room.
        final compact = MediaQuery.sizeOf(context).height < 720;
        return Stack(
          children: [
            CozyBackground(
              child: Scaffold(
                backgroundColor: Colors.transparent,
                drawerScrimColor: AppPalette.drawerScrim,
                drawer: AppDrawer(controller: c),
                // A tip shown behind the open drawer would be "seen" by nobody.
                onDrawerChanged: (open) {
                  _drawerOpen = open;
                  _armIdleTip();
                },
                body: SafeArea(
                  child: Column(
                    children: [
                      _TopBar(controller: c),
                      const SizedBox(height: 4),
                      ModeSwitcher(mode: c.mode, onChanged: _setMode),
                      IdentityHeader(
                        isJourney: isJourney,
                        dailyNumber: c.dailyNumber,
                        level: c.displayedJourneyLevel,
                        chapter: c.journeyChapter,
                        warmUpStep: c.warmUpStep,
                        warmUpOf: GameController.firstStepsLevels,
                        compact: compact,
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
                      SizedBox(height: compact ? 6 : 12),
                      // While "Keep going?" is open its card takes this space.
                      if (!c.awaitingContinue) BoardInfoBar(controller: c),
                      _EndActions(
                        controller: c,
                        onNextLevel: _nextJourneyLevel,
                        onRetry: _retryJourneyLevel,
                        compact: compact,
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
                  : c.awaitingContinue
                      ? 'Keep going or show the answer first'
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

/// Bottom-of-board actions: the "Keep going?" offer on the last miss, and the
/// Journey next / retry buttons once a level is over.
class _EndActions extends StatelessWidget {
  final GameController controller;
  final VoidCallback onNextLevel;
  final VoidCallback onRetry;
  final bool compact;
  const _EndActions({
    required this.controller,
    required this.onNextLevel,
    required this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.awaitingContinue) {
      return _KeepGoingCard(controller: c, compact: compact);
    }
    // A solved Daily: share right from the board (the stats sheet has one too).
    if (c.gameOver && c.won && c.mode == GameMode.daily) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: FilledButton.icon(
          onPressed: () => shareResult(c, from: 'board'),
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Share'),
        ),
      );
    }
    if (!c.gameOver || c.mode != GameMode.journey) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: FilledButton(
        onPressed: c.won ? onNextLevel : onRetry,
        child: Text(c.won ? 'Next level' : 'Try again'),
      ),
    );
  }
}

/// "So close — keep going?" Shown on the last miss, BEFORE the result is
/// recorded, so an extra row can still save the puzzle (and the streak).
/// [compact] (short phones) drops the subtitle and tightens spacing so the
/// board stays visible.
class _KeepGoingCard extends StatelessWidget {
  final GameController controller;
  final bool compact;
  const _KeepGoingCard({required this.controller, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const dense = VisualDensity(horizontal: -2, vertical: -2);
    final buttonStyle = compact
        ? const ButtonStyle(
            visualDensity: dense,
            padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
          )
        : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, compact ? 0 : 2, 16, compact ? 4 : 8),
      child: Container(
        padding: compact
            ? const EdgeInsets.fromLTRB(12, 8, 12, 6)
            : const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: AppPalette.chipFill,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppPalette.coinPillBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.canContinue ? 'So close! Keep going?' : 'Out of rows',
              style: AppType.fredoka(
                  fontSize: compact ? 15 : 16, color: AppPalette.ink),
            ),
            if (!compact) ...[
              const SizedBox(height: 2),
              Text(
                c.canContinue
                    ? 'Get one more row to finish this word.'
                    : 'That was your extra row.',
                style: AppType.nunito(fontSize: 13, color: AppPalette.muted),
              ),
            ],
            SizedBox(height: compact ? 6 : 10),
            Wrap(
              spacing: 8,
              runSpacing: compact ? 2 : 6,
              alignment: WrapAlignment.center,
              children: [
                if (c.canContinue) ...[
                  FilledButton.icon(
                    style: buttonStyle,
                    onPressed: c.continueWithAd,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('Watch ad'),
                  ),
                  OutlinedButton(
                    style: buttonStyle,
                    onPressed: c.continueWithCoins,
                    child:
                        const Text('+1 row · ${CoinRules.extraGuessCost} coins'),
                  ),
                ],
                TextButton(
                  style: buttonStyle,
                  onPressed: c.declineContinue,
                  child: const Text('Show answer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
