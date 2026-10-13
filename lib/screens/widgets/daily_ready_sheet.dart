import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One-time card after a new player's last warm-up level: "You're ready —
/// today's Daily is waiting". Resolves to true when they choose the Daily,
/// false/null when they keep going in Journey or dismiss it.
class DailyReadySheet extends StatelessWidget {
  const DailyReadySheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppPalette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => const DailyReadySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("You're ready",
                textAlign: TextAlign.center,
                style: AppType.fredoka(fontSize: 24, color: AppPalette.ink)),
            const SizedBox(height: 8),
            Text(
              "Today's Daily is waiting — one word, the same for everyone. "
              'Come back each day to build your streak.',
              textAlign: TextAlign.center,
              style: AppType.nunito(
                  fontSize: 14.5, color: AppPalette.muted, height: 1.45),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Play today's Daily"),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep going in Journey'),
            ),
          ],
        ),
      ),
    );
  }
}
