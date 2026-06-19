import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A one-shot confetti burst shown on a win. Self-contained (no plugin): spawns
/// particles that fly up from the bottom and fall under gravity, then calls
/// [onDone] so the caller can remove it. Ignores pointer events.
class CelebrationOverlay extends StatefulWidget {
  final VoidCallback onDone;
  const CelebrationOverlay({super.key, required this.onDone});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final List<_Particle> _particles;

  static const _colors = [
    AppPalette.correct,
    AppPalette.present,
    Color(0xFF6FD3C7),
    Color(0xFFF5D08A),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(44, (i) {
      final angle = -math.pi / 2 + (rng.nextDouble() - 0.5) * 1.4; // mostly up
      final speed = 0.7 + rng.nextDouble() * 0.6;
      return _Particle(
        originX: 0.5 + (rng.nextDouble() - 0.5) * 0.3,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        color: _colors[i % _colors.length],
        size: 6 + rng.nextDouble() * 8,
        spin: (rng.nextDouble() - 0.5) * 12,
        phase: rng.nextDouble(),
      );
    });
    _controller.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_particles, _controller.value),
        ),
      ),
    );
  }
}

class _Particle {
  final double originX, vx, vy, size, spin, phase;
  final Color color;
  _Particle({
    required this.originX,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.spin,
    required this.phase,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1
  _ConfettiPainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const gravity = 1.6;
    final spread = size.height * 0.9;
    final paint = Paint();
    for (final p in particles) {
      // Launch from just below the vertical centre.
      final x = p.originX * size.width + p.vx * spread * t;
      final y = size.height * 0.62 -
          p.vy * spread * t +
          0.5 * gravity * spread * t * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0) * (t < 0.1 ? t / 0.1 : 1.0);
      if (opacity <= 0) continue;
      paint.color = p.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t + p.phase * math.pi * 2);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
