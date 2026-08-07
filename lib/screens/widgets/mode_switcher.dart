import 'package:flutter/material.dart';

import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// Daily ↔ Journey segmented switcher (redesign §6). The selected tab is lifted
/// and carries a lit dot whose colour cues the mode (teal = Daily, amber =
/// Journey). Behaviour unchanged.
class ModeSwitcher extends StatelessWidget {
  final GameMode mode;
  final ValueChanged<GameMode> onChanged;

  const ModeSwitcher({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppPalette.switcherTrackBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.switcherBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tab(GameMode.daily, 'Daily', AppPalette.dailyDot),
            const SizedBox(width: 4),
            _tab(GameMode.journey, 'Journey', AppPalette.journeyDot),
          ],
        ),
      ),
    );
  }

  Widget _tab(GameMode value, String label, Color dot) {
    final selected = mode == value;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: selected ? () {} : () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppPalette.switcherSelTop,
                        AppPalette.switcherSelBottom
                      ])
                  : null,
              borderRadius: BorderRadius.circular(11),
              border: selected
                  ? Border.all(color: const Color(0x10FFFFFF))
                  : null,
              boxShadow: selected
                  ? const [
                      BoxShadow(
                          color: Color(0x4D000000),
                          blurRadius: 6,
                          offset: Offset(0, 2))
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: dot.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppType.fredoka(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppPalette.ink : AppPalette.switcherOffText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
