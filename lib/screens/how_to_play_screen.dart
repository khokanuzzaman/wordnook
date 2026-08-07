import 'package:flutter/material.dart';

import '../models/letter_status.dart';
import '../theme/app_theme.dart';
import 'widgets/cozy_background.dart';
import 'widgets/secondary_header.dart';

/// "How to play" explainer (addendum §E). Warm full screen: intro, three
/// worked examples whose tiles reuse the board's own status styling, and a
/// closing info-note. Uses our own teal / amber / warm-grey palette — never
/// the other game's green / yellow / gray.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  /// Pushes the screen. Resolves to `true` when dismissed via the back button
  /// (used by the first-run flow to distinguish completed from skipped —
  /// closing behaviour is identical either way).
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const HowToPlayScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CozyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SecondaryHeader(title: 'How to play'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Text(
                      'Guess the hidden 5-letter word in six tries. Each guess '
                      'must be a real word — hit enter and the tiles will colour '
                      'to show how close you are.',
                      style: AppType.nunito(
                          fontSize: 15,
                          color: AppPalette.chipText,
                          height: 1.55),
                    ),
                    const SizedBox(height: 22),
                    const _Example(
                      word: 'BREAD',
                      statuses: [
                        LetterStatus.correct,
                        null,
                        null,
                        null,
                        null,
                      ],
                      leadColor: AppPalette.swatchSelLabel,
                      caption: ' — the B is in the word and in the right spot '
                          '(teal).',
                    ),
                    const SizedBox(height: 18),
                    const _Example(
                      word: 'CRUMB',
                      statuses: [
                        null,
                        LetterStatus.present,
                        null,
                        null,
                        null,
                      ],
                      leadColor: AppPalette.coinsAmber,
                      caption: ' — the R is in the word but in the wrong spot '
                          '(amber).',
                    ),
                    const SizedBox(height: 18),
                    const _Example(
                      word: 'TOAST',
                      statuses: [
                        LetterStatus.absent,
                        LetterStatus.absent,
                        LetterStatus.absent,
                        LetterStatus.absent,
                        LetterStatus.absent,
                      ],
                      leadColor: AppPalette.muted,
                      caption: ' — T, O and the last T aren’t in the word '
                          '(grey).',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      decoration: BoxDecoration(
                        color: AppPalette.infoNoteFill,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: AppPalette.infoNoteBorder),
                      ),
                      child: Text(
                        'A new word arrives every day. Keep your streak alive by '
                        'playing daily — no timers, no pressure.',
                        style: AppType.nunito(
                            fontSize: 13.5,
                            color: AppPalette.chipText,
                            height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One worked example: a 5-tile row (only the taught cells are scored) plus a
/// caption whose leading word is coloured to match the state.
class _Example extends StatelessWidget {
  final String word;
  final List<LetterStatus?> statuses;
  final Color leadColor;
  final String caption;
  const _Example({
    required this.word,
    required this.statuses,
    required this.leadColor,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              for (var i = 0; i < word.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                _MiniTile(letter: word[i], status: statuses[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(children: [
            TextSpan(
                text: word,
                style: AppType.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: leadColor)),
            TextSpan(
                text: caption,
                style:
                    AppType.nunito(fontSize: 14, color: AppPalette.muted)),
          ]),
        ),
      ],
    );
  }
}

/// A 46×46 legend tile — the board's scored-tile look at a smaller size,
/// sharing [AppPalette.statusGradient]/[AppPalette.statusGlyph] with the real
/// board so the two never drift.
class _MiniTile extends StatelessWidget {
  final String letter;
  final LetterStatus? status;
  const _MiniTile({required this.letter, required this.status});

  @override
  Widget build(BuildContext context) {
    final scored = status != null && status != LetterStatus.empty;
    final BoxDecoration decoration = scored
        ? BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppPalette.statusGradient(status!)),
            borderRadius: BorderRadius.circular(11),
          )
        : BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppPalette.emptyTop, AppPalette.emptyBottom]),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppPalette.chipBorder, width: 1),
          );
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(
        letter.toUpperCase(),
        style: AppType.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scored ? AppPalette.statusGlyph(status!) : AppPalette.ink,
        ),
      ),
    );
  }
}
