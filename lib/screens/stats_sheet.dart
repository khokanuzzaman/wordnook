import 'package:flutter/material.dart';
import '../models/game_result.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';

class StatsSheet extends StatelessWidget {
  final GameController controller;
  const StatsSheet({super.key, required this.controller});

  static void show(BuildContext context, GameController controller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppPalette.surface,
      builder: (_) => StatsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final GameStats s = controller.stats;
    return Padding(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 20),
          // TODO(share): build an emoji result grid in OUR OWN format
          // (not Wordle's squares) and share via share_plus.
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Share.share(controller.buildShareText());
            },
            icon: const Icon(Icons.share),
            label: const Text('Share result'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
