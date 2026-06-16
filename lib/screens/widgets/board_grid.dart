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

    for (var row = 0; row < GameController.maxGuesses; row++) {
      String letters;
      List<LetterStatus>? statuses;

      if (row < c.guesses.length) {
        letters = c.guesses[row];
        statuses = c.statusesFor(letters);
      } else if (row == c.guesses.length && !c.gameOver) {
        letters = c.current.padRight(c.wordLength);
        statuses = null;
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
            return LetterTile(letter: ch.trim(), status: st);
          }),
        ),
      );
    }

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}
