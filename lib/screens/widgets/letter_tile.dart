import 'package:flutter/material.dart';
import '../../models/letter_status.dart';
import '../../theme/app_theme.dart';

/// A single board tile (redesign §2). Submitted tiles wash in with a short
/// staggered reveal; the active row shows an amber ring, and its first empty
/// cell shows a pulsing caret. Reused by both the real board and the tutorial.
class LetterTile extends StatefulWidget {
  final String letter;
  final LetterStatus status;

  /// Column index, used to stagger the reveal across a row.
  final int column;

  /// True when this letter was GIVEN by a purchased hint (ghost styling).
  final bool isHint;

  /// When false, the reveal wash / typing pop are skipped (reduced motion).
  final bool animate;

  /// True for the next row to play — draws the amber "start here / keep going"
  /// ring on un-typed cells.
  final bool isActiveRow;

  /// True for the single active-row cell that should show the caret.
  final bool showCaret;

  /// 0..1 breathe value for the caret / active ring (1 = static).
  final double pulse;

  const LetterTile({
    super.key,
    required this.letter,
    required this.status,
    this.column = 0,
    this.isHint = false,
    this.animate = true,
    this.isActiveRow = false,
    this.showCaret = false,
    this.pulse = 1.0,
  });

  static const double size = 54;
  static const double gap = 8;
  static const double pitch = size + gap; // 62

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  bool get _scored => widget.status != LetterStatus.empty;

  @override
  void initState() {
    super.initState();
    if (_scored && widget.animate) {
      Future.delayed(Duration(milliseconds: 90 * widget.column), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant LetterTile old) {
    super.didUpdateWidget(old);
    if (!_scored &&
        widget.animate &&
        widget.letter.isNotEmpty &&
        old.letter != widget.letter) {
      _controller
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLetter = widget.letter.isNotEmpty;
    final typed = !_scored && hasLetter;

    late final BoxDecoration decoration;
    late final Color glyphColor;

    if (_scored) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppPalette.statusGradient(widget.status)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: widget.status == LetterStatus.absent
            ? null
            : const [
                BoxShadow(
                    color: Color(0x47000000),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
      );
      glyphColor = AppPalette.statusGlyph(widget.status);
    } else if (typed) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3F3830), Color(0xFF322C25)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1FF4F1EC), width: 1),
      );
      glyphColor = AppPalette.ink;
    } else if (widget.isActiveRow) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.activeTop, AppPalette.activeBottom]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppPalette.activeRing
                .withValues(alpha: 0.38 * (0.7 + 0.3 * widget.pulse)),
            width: 1.5),
      );
      glyphColor = AppPalette.ink;
    } else {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppPalette.emptyTop, AppPalette.emptyBottom]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0AFFF0DC), width: 1),
      );
      glyphColor = AppPalette.ink;
    }

    final Widget child = Container(
      width: LetterTile.size,
      height: LetterTile.size,
      margin: const EdgeInsets.all(LetterTile.gap / 2),
      decoration: decoration,
      alignment: Alignment.center,
      child: widget.showCaret && !hasLetter && !_scored
          ? _caret()
          : Text(
              widget.letter.toUpperCase(),
              style: AppType.fredoka(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: widget.isHint
                    ? AppPalette.forStatus(LetterStatus.correct)
                        .withValues(alpha: 0.55)
                    : glyphColor,
              ),
            ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, c) {
        if (_scored) {
          // Gentle warm colour wash (a soft scale-in rather than a hard flip).
          final t = Curves.easeOut.transform(_controller.value);
          return Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.86 + 0.14 * t, child: c),
          );
        }
        final scale = typed ? 0.9 + 0.1 * _controller.value : 1.0;
        return Transform.scale(scale: scale, child: c);
      },
      child: child,
    );
  }

  Widget _caret() {
    final o = (0.4 + 0.6 * widget.pulse).clamp(0.0, 1.0);
    return Container(
      width: 3,
      height: 26,
      decoration: BoxDecoration(
        color: AppPalette.caret.withValues(alpha: o),
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
              color: AppPalette.caret.withValues(alpha: 0.5 * o),
              blurRadius: 10,
              spreadRadius: 1),
        ],
      ),
    );
  }
}
