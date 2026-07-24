import 'package:flutter/material.dart';

import '../../models/letter_status.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// Two-option segmented control for Daily ↔ Journey.
///
/// Replaces the old app-bar text button, which showed only the CURRENT mode and
/// gave no hint that it was tappable — so new players never discovered Journey.
/// Both options are always visible, and the selected one is clearly filled.
class ModeSwitcher extends StatelessWidget {
  final GameMode mode;
  final ValueChanged<GameMode> onChanged;

  const ModeSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(GameMode.daily, 'Daily', Icons.today_outlined),
            _segment(GameMode.journey, 'Journey', Icons.flag_outlined),
          ],
        ),
      ),
    );
  }

  Widget _segment(GameMode value, String label, IconData icon) {
    final selected = mode == value;
    final accent = AppPalette.forStatus(LetterStatus.correct);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label mode',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          // Tapping the active segment is a no-op (and fires no analytics).
          onTap: selected ? () {} : () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 15,
                    color: selected ? Colors.white : Colors.white54),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: selected ? Colors.white : Colors.white54,
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
