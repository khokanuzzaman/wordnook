import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/countdown.dart';
import '../../logic/journey_labels.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// The info area below the grid (redesign §7). Empty state adds a first-guess
/// prompt; a mode-aware streak chip always shows; the countdown appears ONLY on
/// a solved Daily; a solved Journey shows a "Next: Level N" chip. Presentation
/// only — reads state, never mutates it.
class BoardInfoBar extends StatefulWidget {
  final GameController controller;
  const BoardInfoBar({super.key, required this.controller});

  @override
  State<BoardInfoBar> createState() => _BoardInfoBarState();
}

class _BoardInfoBarState extends State<BoardInfoBar> {
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tick once a second so the solved-Daily countdown stays live — but not
    // when animations are disabled (reduced motion / tests), so nothing hangs.
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _solvedDaily) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  GameController get c => widget.controller;
  bool get _isEmpty => c.guesses.isEmpty && !c.gameOver;
  bool get _solvedDaily => c.mode == GameMode.daily && c.gameOver && c.won;
  bool get _solvedJourney => c.mode == GameMode.journey && c.gameOver && c.won;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[_streakChip()];
    if (_solvedDaily) {
      chips.add(_chip(
        icon: Icons.schedule,
        label: 'Next word in '
            '${formatCountdown(timeUntilNextDaily(), withSeconds: true)}',
        color: AppPalette.muted,
      ));
    } else if (_solvedJourney) {
      chips.add(_chip(
        icon: Icons.arrow_forward,
        label: 'Next: Level ${c.journeyLevel}',
        color: AppPalette.chipText,
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Start with any 5-letter word.',
              style: AppType.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.firstGuessPrompt),
            ),
          ),
        Wrap(spacing: 10, alignment: WrapAlignment.center, children: chips),
      ],
    );
  }

  Widget _streakChip() {
    final label = c.mode == GameMode.journey
        ? levelsClearedLabel(c.journeyLevel - 1)
        : '${c.stats.currentStreak}-day streak';
    return _chip(
      icon: Icons.local_fire_department,
      label: label,
      color: AppPalette.chipText,
      iconColor: AppPalette.present,
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppPalette.chipFill,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppPalette.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? color),
          const SizedBox(width: 7),
          Text(label,
              style: AppType.nunito(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
