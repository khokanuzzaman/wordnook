import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Warm-evening background (redesign §5): a radial warm gradient with a lamp
/// glow near the top, deepening to near-black at the edges and bottom via a
/// vignette. Never pure black. Presentation only; wraps the screen content.
class CozyBackground extends StatelessWidget {
  final Widget child;
  const CozyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.82),
          radius: 1.25,
          colors: [AppPalette.bgTop, AppPalette.bgMid, AppPalette.bgBottom],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Warm lamp glow near the top.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1.0),
                    radius: 0.95,
                    colors: [AppPalette.bgGlow, Color(0x00E0A857)],
                    stops: [0.0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          // Vignette: darken the edges…
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.1),
                    radius: 1.1,
                    colors: [Color(0x00000000), Color(0x8C000000)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          // …and deepen the bottom.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x80000000)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
