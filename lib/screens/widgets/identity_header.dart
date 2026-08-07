import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The identity block (redesign §7): kicker + title + subtitle that tell the
/// player exactly what puzzle they're on. Mode-aware, driven by the real daily
/// number / journey level. Presentation only.
class IdentityHeader extends StatelessWidget {
  final bool isJourney;
  final int dailyNumber;
  final int level;
  final int chapter;

  const IdentityHeader({
    super.key,
    required this.isJourney,
    required this.dailyNumber,
    required this.level,
    required this.chapter,
  });

  @override
  Widget build(BuildContext context) {
    final kicker = isJourney ? 'JOURNEY · CHAPTER $chapter' : "TODAY'S PUZZLE";
    final title = isJourney ? 'Level $level' : 'Daily Word #$dailyNumber';
    final subtitle = isJourney
        ? 'Guess the hidden 5-letter word to advance.'
        : 'Guess the hidden 5-letter word in six tries.';
    final kickerColor =
        isJourney ? AppPalette.journeyKicker : AppPalette.dailyKicker;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        children: [
          Text(
            kicker,
            textAlign: TextAlign.center,
            style: AppType.nunito(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: kickerColor,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.fredoka(fontSize: 27, color: AppPalette.ink),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppType.nunito(fontSize: 14, color: AppPalette.muted),
          ),
        ],
      ),
    );
  }
}
