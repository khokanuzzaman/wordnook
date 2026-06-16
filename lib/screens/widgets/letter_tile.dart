import 'package:flutter/material.dart';
import '../../models/letter_status.dart';
import '../../theme/app_theme.dart';

class LetterTile extends StatelessWidget {
  final String letter;
  final LetterStatus status;

  const LetterTile({super.key, required this.letter, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.forStatus(status);
    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: status == LetterStatus.empty ? AppPalette.border : color,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
