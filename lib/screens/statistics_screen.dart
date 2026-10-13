import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/game_result.dart';
import '../services/analytics_service.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'widgets/banner_ad_slot.dart';
import 'widgets/cozy_background.dart';
import 'widgets/secondary_header.dart';

/// Statistics (addendum §C): a warm full screen — cozy streak line, four stat
/// cards, the guess-distribution bars (best row highlighted), and Share. Daily
/// auto-opens this after a result; the stats icon and menu open it on demand.
class StatisticsScreen extends StatelessWidget {
  final GameController controller;
  const StatisticsScreen({super.key, required this.controller});

  static Future<void> show(BuildContext context, GameController controller) {
    AnalyticsService.instance.logEvent(AnalyticsEvents.statsOpened);
    return Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => StatisticsScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return CozyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          // Rebuilds after a streak restore so the numbers update live.
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final GameStats s = controller.stats;
              return Column(
                children: [
                  const SecondaryHeader(title: 'Statistics'),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        _StreakLine(streak: s.currentStreak),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _StatCard(
                                value: '${s.gamesPlayed}', label: 'Played'),
                            const SizedBox(width: 9),
                            _StatCard(
                                value: '${(s.winRate * 100).round()}',
                                label: 'Win %'),
                            const SizedBox(width: 9),
                            _StatCard(
                                value: '${s.currentStreak}', label: 'Streak'),
                            const SizedBox(width: 9),
                            _StatCard(value: '${s.bestStreak}', label: 'Best'),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text('GUESS DISTRIBUTION',
                            style: AppType.nunito(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: AppPalette.dailyKicker)),
                        const SizedBox(height: 14),
                        _Distribution(stats: s, animate: !reduceMotion),
                        if (controller.canRestoreStreak) ...[
                          const SizedBox(height: 22),
                          _RestoreStreakButton(onTap: controller.restoreStreak),
                        ],
                        const SizedBox(height: 22),
                        _ShareButton(controller: controller),
                        // Daily stays clean: the banner is a Journey-only slot,
                        // and its spacer goes with it (no empty gap).
                        if (controller.mode == GameMode.journey) ...[
                          const SizedBox(height: 14),
                          const BannerAdSlot(),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A cozy one-liner above the cards, derived from the real current streak.
class _StreakLine extends StatelessWidget {
  final int streak;
  const _StreakLine({required this.streak});

  @override
  Widget build(BuildContext context) {
    final String emoji;
    final String text;
    if (streak <= 0) {
      emoji = '🌱';
      text = 'No streak yet — today’s a lovely day to start one.';
    } else {
      emoji = '🔥';
      text = 'You’re on a $streak-day streak — cozy work.';
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: AppType.nunito(
                  fontSize: 14, color: AppPalette.chipText, height: 1.4)),
        ),
      ],
    );
  }
}

/// One of the four stat cards.
class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: AppPalette.chipFill,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppPalette.chipBorder),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: AppType.fredoka(
                      fontSize: 30, color: AppPalette.ink, height: 1)),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: AppType.nunito(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppPalette.muted)),
          ],
        ),
      ),
    );
  }
}

/// Horizontal bars for wins-in-N-guesses (rows 1..maxGuesses); the max row is
/// highlighted in bright teal.
class _Distribution extends StatelessWidget {
  final GameStats stats;
  final bool animate;
  const _Distribution({required this.stats, required this.animate});

  @override
  Widget build(BuildContext context) {
    final dist = stats.guessDistribution;
    final maxCount = dist.skip(1).fold<int>(0, (m, v) => v > m ? v : m);
    return Column(
      children: [
        for (var n = 1; n < dist.length; n++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _DistRow(
              rowNumber: n,
              count: dist[n],
              maxCount: maxCount,
              isBest: maxCount > 0 && dist[n] == maxCount,
              animate: animate,
            ),
          ),
      ],
    );
  }
}

class _DistRow extends StatelessWidget {
  final int rowNumber;
  final int count;
  final int maxCount;
  final bool isBest;
  final bool animate;
  const _DistRow({
    required this.rowNumber,
    required this.count,
    required this.maxCount,
    required this.isBest,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    // width = max(11%, count/max × 100%).
    final frac = maxCount == 0 ? 0.11 : (count / maxCount).clamp(0.11, 1.0);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 12,
          child: Text('$rowNumber',
              style:
                  AppType.fredoka(fontSize: 14, color: AppPalette.iconStroke)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 26,
              color: AppPalette.distTrack,
              child: Align(
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: animate ? 0.0 : frac, end: frac),
                  duration: animate
                      ? const Duration(milliseconds: 600)
                      : Duration.zero,
                  curve: Curves.easeOut,
                  builder: (context, t, __) => FractionallySizedBox(
                    widthFactor: t,
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: isBest
                              ? const [
                                  AppPalette.distBestStart,
                                  AppPalette.distBestEnd
                                ]
                              : const [
                                  AppPalette.distNormalStart,
                                  AppPalette.distNormalEnd
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$count',
                          style: AppType.fredoka(
                              fontSize: 13,
                              color: isBest
                                  ? AppPalette.distBestCount
                                  : AppPalette.distNormalCount)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width teal share button (addendum §C).
class _ShareButton extends StatelessWidget {
  final GameController controller;
  const _ShareButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final enabled = controller.shareText != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: enabled
              ? () {
                  AnalyticsService.instance.logEvent(
                    AnalyticsEvents.shareResult,
                    {AnalyticsParams.mode: controller.mode.name},
                  );
                  SharePlus.instance
                      .share(ShareParams(text: controller.shareText!));
                }
              : null,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppPalette.tealBtnStart, AppPalette.tealBtnEnd],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                          color: Color(0x804F9B8E),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                          spreadRadius: -8)
                    ]
                  : null,
            ),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.ios_share,
                      size: 18, color: AppPalette.onTealInk),
                  const SizedBox(width: 8),
                  Text('Share result',
                      style: AppType.fredoka(
                          fontSize: 16, color: AppPalette.onTealInk)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rewarded "restore streak" — kept from the old sheet, warm-styled. Only shown
/// when the controller says a restore is available.
class _RestoreStreakButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RestoreStreakButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppPalette.infoNoteFill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppPalette.infoNoteBorder),
          ),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department,
                    size: 18, color: AppPalette.coinsAmber),
                const SizedBox(width: 8),
                Text('Restore streak (watch ad)',
                    style: AppType.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.coinsAmber)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
