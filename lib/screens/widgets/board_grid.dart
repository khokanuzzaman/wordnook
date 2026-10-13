import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/letter_status.dart';
import '../../state/game_controller.dart';
import 'letter_tile.dart';

/// The real game board (redesign §2). Marks the next unplayed row as the active
/// row (amber ring), shows a pulsing caret on its first empty cell, and washes
/// submitted rows in. Reuses [LetterTile].
class BoardGrid extends StatefulWidget {
  final GameController controller;
  const BoardGrid({super.key, required this.controller});

  @override
  State<BoardGrid> createState() => _BoardGridState();
}

class _BoardGridState extends State<BoardGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour reduced motion: only run the caret/ring breathe when animations
    // are enabled (also keeps pumpAndSettle from hanging in tests).
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _pulse
        ..stop()
        ..value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final c = widget.controller;
    final rowCount = math.max(
      GameController.maxGuesses,
      c.guesses.length + (c.acceptingInput ? 1 : 0),
    );
    // No active row while the game is over OR the "Keep going?" offer is open.
    final activeRow = c.acceptingInput ? c.guesses.length : -1;
    final caretCol = c.current.length; // first empty cell in the active row

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final pulse = reduce ? 1.0 : _pulse.value;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < rowCount; row++)
                _row(c, row, activeRow, caretCol, pulse, !reduce),
            ],
          ),
        );
      },
    );
  }

  Widget _row(GameController c, int row, int activeRow, int caretCol,
      double pulse, bool animate) {
    String letters;
    List<LetterStatus>? statuses;
    if (row < c.guesses.length) {
      letters = c.guesses[row];
      statuses = c.statusesFor(letters);
    } else if (row == activeRow) {
      letters = c.current.padRight(c.wordLength);
      statuses = null;
    } else {
      letters = ' ' * c.wordLength;
      statuses = null;
    }
    final isActive = row == activeRow;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(c.wordLength, (col) {
        final ch = col < letters.length ? letters[col] : ' ';
        final st = statuses == null ? LetterStatus.empty : statuses[col];
        final showCaret =
            isActive && col == caretCol && caretCol < c.wordLength;
        return LetterTile(
          key: ValueKey('$row-$col-${st == LetterStatus.empty ? 'e' : 'r'}'),
          letter: ch.trim(),
          status: st,
          column: col,
          animate: animate,
          isActiveRow: isActive,
          showCaret: showCaret,
          pulse: pulse,
        );
      }),
    );
  }
}
