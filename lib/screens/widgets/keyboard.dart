import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/letter_status.dart';
import '../../theme/app_theme.dart';

/// On-screen QWERTY keyboard (redesign §4). Warm key faces; keys reflect their
/// letter state. Depends only on primitives so both the real game and the
/// isolated tutorial reuse it.
class Keyboard extends StatelessWidget {
  final Map<String, LetterStatus> keyStatus;
  final ValueChanged<String> onKey;

  /// Letters revealed by a purchased hint — outlined (empty in the tutorial).
  final Set<String> hintedLetters;

  /// Short phones (e.g. 360×640): slightly shorter keys so the board keeps room.
  final bool compact;

  const Keyboard({
    super.key,
    required this.keyStatus,
    required this.onKey,
    this.hintedLetters = const {},
    this.compact = false,
  });

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 4, 7, 8),
      child: Column(
        children: [
          for (var r = 0; r < _rows.length; r++)
            Padding(
              padding: EdgeInsets.only(bottom: compact ? 5 : 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (r == 2) _key(context, 'ENTER', flex: 3),
                  for (final ch in _rows[r].split('')) _key(context, ch),
                  if (r == 2) _key(context, 'DEL', flex: 3),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static List<Color> _grad(Color base) {
    final hsl = HSLColor.fromColor(base);
    return [
      hsl.withLightness((hsl.lightness + 0.055).clamp(0.0, 1.0)).toColor(),
      hsl.withLightness((hsl.lightness - 0.055).clamp(0.0, 1.0)).toColor(),
    ];
  }

  Widget _key(BuildContext context, String label, {int flex = 2}) {
    final status = keyStatus[label];
    final isHinted = hintedLetters.contains(label);

    List<Color> colors;
    Color glyph;
    if (status == null || status == LetterStatus.empty) {
      colors = const [AppPalette.keyFaceTop, AppPalette.keyFaceBottom];
      glyph = AppPalette.keyGlyph;
    } else if (status == LetterStatus.absent) {
      colors = const [AppPalette.keyAbsentTop, AppPalette.keyAbsentBottom];
      glyph = AppPalette.keyAbsentGlyph;
    } else {
      final base = AppPalette.forStatus(status);
      colors = _grad(base);
      glyph = base.computeLuminance() > 0.55
          ? AppPalette.inkOnAmber
          : AppPalette.ink;
    }

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onKey(label);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: compact ? 40 : 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: colors,
              ),
              borderRadius: BorderRadius.circular(10),
              border: isHinted
                  ? Border.all(
                      color: AppPalette.forStatus(LetterStatus.correct),
                      width: 2)
                  : Border.all(color: const Color(0x0FFFF0DC), width: 1),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 0,
                    offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              label,
              style: AppType.fredoka(
                fontWeight: FontWeight.w600,
                fontSize: label.length > 1 ? 12.5 : 17,
                color: glyph,
                letterSpacing: label.length > 1 ? 0.5 : 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
