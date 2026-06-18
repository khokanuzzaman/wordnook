import 'package:flutter/material.dart';

import '../branding.dart';
import '../theme/app_theme.dart';

/// First-run onboarding / "How to play" explainer. Describes the rules and our
/// own colour legend (teal / amber / slate — not the other game's palette).
class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppPalette.surface,
      isScrollControlled: true,
      builder: (_) => const HowToPlaySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to play',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 4),
            const Text(Branding.appTagline,
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text(
              'Guess the hidden 5-letter word in 6 tries. Each guess must be a '
              'real word. After each guess, the tiles show how close you were:',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            const _LegendRow(
              color: AppPalette.correct,
              letter: 'T',
              text: 'Right letter, right spot.',
            ),
            const SizedBox(height: 12),
            const _LegendRow(
              color: AppPalette.present,
              letter: 'R',
              text: 'Right letter, wrong spot.',
            ),
            const SizedBox(height: 12),
            const _LegendRow(
              color: AppPalette.absent,
              letter: 'X',
              text: 'Not in the word.',
            ),
            const SizedBox(height: 24),
            const Text(
              'A new Daily puzzle drops every day — keep your streak alive. '
              'Journey mode is an endless run of themed levels to play any time.',
              style: TextStyle(height: 1.4, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String letter;
  final String text;
  const _LegendRow(
      {required this.color, required this.letter, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(letter,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }
}
