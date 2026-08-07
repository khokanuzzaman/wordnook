import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// The cozy stall nudge (design option A · Sticky note). Warm, dismissible,
/// never blocks the board. Shown after a couple of guesses with no new green.
class StallNudge extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const StallNudge({super.key, required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232019), Color(0xFF1D1A14)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppPalette.present.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: AppPalette.present.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.present,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 10, height: 10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message,
                style: AppType.nunito(
                    fontSize: 14.5, color: AppPalette.ink, height: 1.35),
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: AppPalette.muted),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
