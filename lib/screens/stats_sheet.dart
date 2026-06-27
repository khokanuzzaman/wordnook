import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_result.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import 'widgets/banner_ad_slot.dart';

class StatsSheet extends StatelessWidget {
  final GameController controller;
  const StatsSheet({super.key, required this.controller});

  static void show(BuildContext context, GameController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      builder: (_) => StatsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds after a streak restore so the numbers update live.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final GameStats s = controller.stats;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('Played', '${s.gamesPlayed}'),
                  _stat('Win %', '${(s.winRate * 100).round()}'),
                  _stat('Streak', '${s.currentStreak}'),
                  _stat('Best', '${s.bestStreak}'),
                ],
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Guess distribution',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              _Distribution(stats: s),
              if (controller.canRestoreStreak) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.present,
                  ),
                  onPressed: controller.restoreStreak,
                  icon: const Icon(Icons.local_fire_department),
                  label: const Text('Restore streak (watch ad)'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.shareText == null
                    ? null
                    : () {
                        final text = controller.shareText!;
                        Navigator.pop(context);
                        Share.share(text);
                      },
                icon: const Icon(Icons.share),
                label: const Text('Share result'),
              ),
              const SizedBox(height: 12),
              const BannerAdSlot(),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

/// Horizontal bars for wins-in-N-guesses (rows 1..maxGuesses).
class _Distribution extends StatelessWidget {
  final GameStats stats;
  const _Distribution({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dist = stats.guessDistribution;
    final maxCount =
        dist.skip(1).fold<int>(1, (m, v) => v > m ? v : m); // avoid /0
    return Column(
      children: [
        for (var n = 1; n < dist.length; n++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text('$n',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final frac = dist[n] / maxCount;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 22,
                          width: (constraints.maxWidth * frac)
                              .clamp(24.0, constraints.maxWidth),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: dist[n] > 0
                                ? AppPalette.correct
                                : AppPalette.absent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${dist[n]}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
