import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/letter_status.dart';
import '../../state/game_controller.dart';
import 'letter_tile.dart';

class BoardGrid extends StatelessWidget {
  final GameController controller;
  const BoardGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final rows = <Widget>[];

    // Normally maxGuesses rows; if a rewarded extra guess re-opened the game
    // past the limit, grow to fit the new active row.
    final rowCount = math.max(
      GameController.maxGuesses,
      c.guesses.length + (c.gameOver ? 0 : 1),
    );

    for (var row = 0; row < rowCount; row++) {
      String letters;
      List<LetterStatus>? statuses;
      var isActiveRow = false;

      if (row < c.guesses.length) {
        letters = c.guesses[row];
        statuses = c.statusesFor(letters);
      } else if (row == c.guesses.length && !c.gameOver) {
        letters = c.current.padRight(c.wordLength);
        statuses = null;
        isActiveRow = true;
      } else {
        letters = ' ' * c.wordLength;
        statuses = null;
      }

      rows.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(c.wordLength, (col) {
            final ch = col < letters.length ? letters[col] : ' ';
            final st = statuses == null ? LetterStatus.empty : statuses[col];
            // A purchased hint shows as a ghost letter in the row you're
            // typing, until you actually type over that position.
            final hint = c.revealedHints[col];
            final showHint = isActiveRow && ch.trim().isEmpty && hint != null;
            // Key flips from "empty" to "revealed" on submit, remounting the
            // tile so its reveal animation plays exactly once.
            return LetterTile(
              key: ValueKey('$row-$col-'
                  '${st == LetterStatus.empty ? 'e' : 'r'}${showHint ? 'h' : ''}'),
              letter: showHint ? hint : ch.trim(),
              status: st,
              column: col,
              isHint: showHint,
            );
          }),
        ),
      );
    }

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
