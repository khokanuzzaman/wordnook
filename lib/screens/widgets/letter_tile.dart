import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/letter_status.dart';
import '../../theme/app_theme.dart';

/// A single board tile. Submitted tiles (status != empty) flip in with a short
/// staggered reveal; empty tiles render statically and "pop" when a letter is
/// typed in.
class LetterTile extends StatefulWidget {
  final String letter;
  final LetterStatus status;

  /// Column index, used to stagger the reveal flip across a row.
  final int column;

  const LetterTile({
    super.key,
    required this.letter,
    required this.status,
    this.column = 0,
  });

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  bool get _revealed => widget.status != LetterStatus.empty;

  @override
  void initState() {
    super.initState();
    if (_revealed) {
      // Stagger each column so the row reveals left-to-right.
      Future.delayed(Duration(milliseconds: 90 * widget.column), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1; // empty tiles are fully "settled".
    }
  }

  @override
  void didUpdateWidget(covariant LetterTile old) {
    super.didUpdateWidget(old);
    // A letter typed into an empty tile gives a quick pop.
    if (!_revealed && widget.letter.isNotEmpty && old.letter != widget.letter) {
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
    final color = AppPalette.forStatus(widget.status);
    final isEmpty = widget.status == LetterStatus.empty;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_revealed) {
          // Flip around the X axis: the tile rotates in to reveal its colour.
          final t = Curves.easeOutBack.transform(_controller.value);
          final angle = (1 - t) * (math.pi / 2);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(angle),
            child: child,
          );
        }
        // Typing pop: subtle scale from a keystroke.
        final scale = isEmpty && widget.letter.isNotEmpty
            ? 0.9 + 0.1 * _controller.value
            : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isEmpty
                ? (widget.letter.isNotEmpty
                    ? AppPalette.keyIdle
                    : AppPalette.border)
                : color,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.letter.toUpperCase(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
