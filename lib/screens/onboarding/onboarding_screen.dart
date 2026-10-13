import 'package:flutter/material.dart';

import '../../branding.dart';
import '../../logic/coin_rules.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../state/onboarding_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/cozy_background.dart';
import '../widgets/keyboard.dart';
import 'widgets/stall_nudge.dart';
import 'widgets/tether_legend.dart';
import 'widgets/tutorial_board.dart';
import 'widgets/win_sheet.dart';

/// First-run interactive tutorial. Teaches by playing a fixed puzzle (BREAD)
/// to a win, then hands off to the real daily. Fully isolated from real game
/// state until the very end (see [OnboardingController]).
class OnboardingScreen extends StatefulWidget {
  final StorageService storage;

  /// Called once the tutorial finishes (win or skip). The parent swaps in the
  /// real game screen.
  final VoidCallback onFinish;

  const OnboardingScreen({
    super.key,
    required this.storage,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final OnboardingController c = OnboardingController();
  final Set<OnboardingStep> _reportedSteps = {};
  bool _winShown = false;
  bool _finished = false;
  bool _reminderTurnedOn = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onChange);
    AnalyticsService.instance.logEvent(AnalyticsEvents.onboardingStarted);
    _reportStep(c.step); // invite
  }

  @override
  void dispose() {
    c.removeListener(_onChange);
    c.dispose();
    super.dispose();
  }

  void _onChange() {
    _reportStep(c.step);
    if (c.solved && !_winShown) {
      _winShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showWin();
      });
    }
    if (mounted) setState(() {});
  }

  void _reportStep(OnboardingStep step) {
    if (!_reportedSteps.add(step)) return;
    AnalyticsService.instance.logEvent(
      AnalyticsEvents.onboardingStepReached,
      {AnalyticsParams.step: _stepName(step)},
    );
  }

  static String _stepName(OnboardingStep s) => switch (s) {
        OnboardingStep.invite => AnalyticsOnboardingSteps.invite,
        OnboardingStep.reveal => AnalyticsOnboardingSteps.reveal,
        OnboardingStep.solve => AnalyticsOnboardingSteps.solve,
        OnboardingStep.win => AnalyticsOnboardingSteps.win,
      };

  Future<void> _finish({required bool won}) async {
    if (_finished) return;
    _finished = true;
    await widget.storage.setOnboardingSeen();
    // Reminder is opt-in: if the player never tapped "Turn on" (or skipped),
    // leave it OFF so nothing nudges them and Settings reflects the truth. The
    // default is on, so we set it explicitly here.
    if (!_reminderTurnedOn) {
      await widget.storage.setReminderEnabled(false);
    }
    if (await widget.storage.grantWelcomeCoins(CoinRules.welcomeCoins)) {
      AnalyticsService.instance.logEvent(AnalyticsEvents.coinsEarned, {
        AnalyticsParams.amount: CoinRules.welcomeCoins,
        AnalyticsParams.source: AnalyticsSources.welcome,
      });
    }
    if (won) {
      await widget.storage.beginStreakFromOnboarding();
      AnalyticsService.instance.logEvent(AnalyticsEvents.onboardingCompleted);
    } else {
      AnalyticsService.instance.logEvent(AnalyticsEvents.onboardingSkipped);
    }
    if (mounted) widget.onFinish();
  }

  Future<bool> _turnOnReminder() async {
    try {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) return false;
      await widget.storage.setReminderEnabled(true);
      await NotificationService.instance.scheduleDailyReminder(
        hour: widget.storage.reminderHour,
        minute: widget.storage.reminderMinute,
      );
      _reminderTurnedOn = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _showWin() {
    final label = TimeOfDay(
      hour: widget.storage.reminderHour,
      minute: widget.storage.reminderMinute,
    ).format(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppPalette.surface,
      barrierColor: const Color(0x73090B0C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => WinSheet(
        solvedInGuesses: c.guesses.length,
        streakCount: 1,
        reminderTimeLabel: label,
        onTurnOnReminder: _turnOnReminder,
        onPlayDaily: () {
          Navigator.of(sheetContext).pop();
          _finish(won: true);
        },
        onMaybeLater: () {
          Navigator.of(sheetContext).pop();
          _finish(won: true);
        },
      ),
    );
  }

  String get _guidance => switch (c.step) {
        OnboardingStep.invite => 'Start with any 5-letter word.',
        OnboardingStep.reveal =>
          "You played a word — here's what the colours are telling you.",
        OnboardingStep.solve => "Keep going. You're closer than it feels.",
        // The win sheet owns the celebration copy; the line behind it is blank.
        OnboardingStep.win => '',
      };

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CozyBackground(
        child: SafeArea(
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 4, 26, 0),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Text(
                    _guidance,
                    textAlign: TextAlign.center,
                    style: AppType.nunito(
                        fontSize: 14.5, color: AppPalette.muted, height: 1.45),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _boardArea(animate),
            const Spacer(),
            if (c.step == OnboardingStep.solve && c.showStallNudge) ...[
              StallNudge(
                message: c.stallHint(),
                onDismiss: c.dismissStallNudge,
              ),
              const SizedBox(height: 12),
            ],
            Keyboard(keyStatus: c.keyStatus, onKey: c.onKey),
            const SizedBox(height: 8),
          ],
        ),
      ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
      child: Row(
        children: [
          const SizedBox(width: 56),
          Expanded(
            child: Center(
              child: Text(Branding.appName,
                  style: AppType.fredoka(
                      fontSize: 21, color: AppPalette.ink, letterSpacing: 0.3)),
            ),
          ),
          TextButton(
            onPressed: _finished ? null : () => _finish(won: false),
            child: Text('Skip',
                style: AppType.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.faint)),
          ),
        ],
      ),
    );
  }

  Widget _boardArea(bool animate) {
    final showLegend = c.step == OnboardingStep.reveal && c.guesses.isNotEmpty;
    return SizedBox(
      width: TutorialBoard.width,
      height: TutorialBoard.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TutorialBoard(controller: c, animate: animate),
          if (showLegend)
            Positioned(
              top: TutorialBoard.cell,
              left: 0,
              right: 0,
              child: TetherLegend(
                rowStatuses: c.statusesFor(c.guesses.first),
                chips: c.revealLegend(),
              ),
            ),
        ],
      ),
    );
  }
}
