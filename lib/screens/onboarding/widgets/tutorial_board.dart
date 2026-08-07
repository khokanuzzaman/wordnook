import 'package:flutter/material.dart';

import '../../../models/letter_status.dart';
import '../../../state/onboarding_controller.dart';
import '../../widgets/letter_tile.dart';

/// The tutorial board. Composes the SAME [LetterTile] the real game uses, so it
/// is pixel-consistent with the live board, but is driven by the isolated
/// [OnboardingController] instead of a GameController.
class TutorialBoard extends StatelessWidget {
  final OnboardingController controller;

  /// Cell pitch (tile + gap) — sourced from [LetterTile] so the two stay in sync.
  static const double cell = LetterTile.pitch;
  static const int cols = OnboardingController.wordLength;
  static const int rows = OnboardingController.maxRows;

  static const double width = cell * cols;
  static const double height = cell * rows;

  const TutorialBoard({
    super.key,
    required this.controller,
    required this.animate,
  });

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final activeRow = c.guesses.length;

    return SizedBox(
      width: width,
      height: height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < rows; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cols, (col) {
                String letters;
                List<LetterStatus>? statuses;
                if (row < c.guesses.length) {
                  letters = c.guesses[row];
                  statuses = c.statusesFor(letters);
                } else if (row == activeRow && !c.solved) {
                  letters = c.current.padRight(cols);
                  statuses = null;
                } else {
                  letters = ' ' * cols;
                  statuses = null;
                }
                final ch = col < letters.length ? letters[col] : ' ';
                final st = statuses == null ? LetterStatus.empty : statuses[col];
                return LetterTile(
                  key: ValueKey(
                      '$row-$col-${st == LetterStatus.empty ? 'e' : 'r'}'),
                  letter: ch.trim(),
                  status: st,
                  column: col,
                  animate: animate,
                );
              }),
            ),
        ],
      ),
    );
  }
}
