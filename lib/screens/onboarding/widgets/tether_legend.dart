import 'package:flutter/material.dart';

import '../../../models/letter_status.dart';
import '../../../state/onboarding_controller.dart';
import '../../../theme/app_theme.dart';
import 'tutorial_board.dart';

/// "Your row, decoded" — the Tether legend (design option A). Thin ticks drop
/// from each tile in the just-played row into a card that names each colour,
/// using the player's own letters.
class TetherLegend extends StatelessWidget {
  final List<LetterStatus> rowStatuses; // one per column, from the first guess
  final List<LegendChip> chips;

  const TetherLegend({
    super.key,
    required this.rowStatuses,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ticks(),
        const SizedBox(height: 6),
        _card(context),
      ],
    );
  }

  Widget _ticks() {
    Color tickColor(LetterStatus s) => switch (s) {
          LetterStatus.correct => AppPalette.forStatus(LetterStatus.correct),
          LetterStatus.present => AppPalette.forStatus(LetterStatus.present),
          _ => AppPalette.muted.withValues(alpha: 0.28),
        };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < TutorialBoard.cols; i++)
          SizedBox(
            width: TutorialBoard.cell,
            child: Center(
              child: Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: tickColor(
                      i < rowStatuses.length ? rowStatuses[i] : LetterStatus.empty),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      width: TutorialBoard.width,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.ink.withValues(alpha: 0.07)),
        boxShadow: const [
          BoxShadow(
            color: Color(0xB3000000),
            blurRadius: 28,
            offset: Offset(0, 14),
            spreadRadius: -14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your row, decoded',
              style: AppType.fredoka(
                  fontSize: 15, fontWeight: FontWeight.w500, color: AppPalette.ink)),
          const SizedBox(height: 10),
          for (final chip in chips) ...[
            _row(chip),
            if (chip != chips.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _row(LegendChip chip) {
    return Row(
      children: [
        _chip(chip),
        const SizedBox(width: 12),
        _rule(chip.status),
      ],
    );
  }

  Widget _chip(LegendChip chip) {
    final isGrey = chip.status == LetterStatus.absent;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.forStatus(chip.status),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        chip.letter,
        style: AppType.fredoka(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isGrey ? AppPalette.muted : Colors.white,
        ),
      ),
    );
  }

  Widget _rule(LetterStatus status) {
    final base = AppType.nunito(fontSize: 15, color: AppPalette.ink);
    switch (status) {
      case LetterStatus.correct:
        return Text.rich(TextSpan(style: base, children: [
          const TextSpan(text: 'right letter, '),
          TextSpan(
            text: 'right spot',
            style: base.copyWith(
                color: const Color(0xFF8FD3C6), fontWeight: FontWeight.w700),
          ),
        ]));
      case LetterStatus.present:
        return Text.rich(TextSpan(style: base, children: [
          const TextSpan(text: 'right letter, '),
          TextSpan(
            text: 'wrong spot',
            style: base.copyWith(
                color: AppPalette.forStatus(LetterStatus.present),
                fontWeight: FontWeight.w700),
          ),
        ]));
      default:
        return Text('not in the word',
            style: base.copyWith(color: AppPalette.muted));
    }
  }
}
