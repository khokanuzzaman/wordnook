import 'package:flutter/material.dart';

import '../../../models/letter_status.dart';
import '../../../state/game_controller.dart';
import '../../../theme/app_theme.dart';

/// The win bottom sheet (screen 4): gentle celebration, the streak card where
/// the real streak begins, a soft reminder ask (never a native prompt), a light
/// Journey mention, and the two CTAs that both land on the real daily.
class WinSheet extends StatefulWidget {
  final int solvedInGuesses;
  final int streakCount;
  final String reminderTimeLabel;

  /// Triggers the OS notification permission + enables the reminder. Returns
  /// true only if the reminder is actually on afterwards. Called ONLY when the
  /// user taps "Turn on".
  final Future<bool> Function() onTurnOnReminder;

  /// Primary CTA: leave the tutorial for the warm-up levels.
  final VoidCallback onContinue;
  final VoidCallback onMaybeLater;

  const WinSheet({
    super.key,
    required this.solvedInGuesses,
    required this.streakCount,
    required this.reminderTimeLabel,
    required this.onTurnOnReminder,
    required this.onContinue,
    required this.onMaybeLater,
  });

  @override
  State<WinSheet> createState() => _WinSheetState();
}

class _WinSheetState extends State<WinSheet> {
  bool _reminderOn = false;
  bool _busy = false;

  Future<void> _turnOn() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await widget.onTurnOnReminder();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reminderOn = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scrolls on short phones (360×640) instead of overflowing.
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('SOLVED IN ${widget.solvedInGuesses}',
                textAlign: TextAlign.center,
                style: AppType.nunito(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.correct,
                  letterSpacing: 1.2,
                )),
            const SizedBox(height: 6),
            Text('Nicely done.',
                textAlign: TextAlign.center,
                style: AppType.fredoka(fontSize: 30, color: AppPalette.ink)),
            const SizedBox(height: 20),
            _streakCard(),
            const SizedBox(height: 14),
            _reminderCard(),
            const SizedBox(height: 18),
            _journeyLine(),
            const SizedBox(height: 18),
            _primaryCta(),
            const SizedBox(height: 6),
            TextButton(
              onPressed: widget.onMaybeLater,
              child: Text('Maybe later',
                  style: AppType.nunito(
                      fontSize: 14, color: AppPalette.muted)),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _cardBox => BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.ink.withValues(alpha: 0.07)),
      );

  Widget _streakCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardBox,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your streak starts today',
                        style: AppType.fredoka(
                            fontSize: 16, color: AppPalette.ink)),
                    const SizedBox(height: 3),
                    Text('Come back tomorrow to make it two.',
                        style: AppType.nunito(
                            fontSize: 13, color: AppPalette.muted)),
                  ],
                ),
              ),
              _streakBadge(),
            ],
          ),
          const SizedBox(height: 14),
          _weekDots(),
        ],
      ),
    );
  }

  Widget _streakBadge() {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppPalette.present.withValues(alpha: 0.16),
        border: Border.all(color: AppPalette.present.withValues(alpha: 0.5)),
      ),
      child: Text('${widget.streakCount}',
          style: AppType.fredoka(
              fontSize: 20, fontWeight: FontWeight.w700, color: AppPalette.present)),
    );
  }

  Widget _weekDots() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: i == 0
                          ? LinearGradient(colors: [
                              AppPalette.forStatus(LetterStatus.correct),
                              AppPalette.present,
                            ])
                          : null,
                      color: i == 0
                          ? null
                          : AppPalette.ink.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      style: AppType.nunito(
                          fontSize: 11, color: AppPalette.muted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _reminderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF20241E), Color(0xFF1A1E19)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.present.withValues(alpha: 0.15)),
      ),
      child: _reminderOn
          ? Row(
              children: [
                Icon(Icons.check_circle,
                    color: AppPalette.forStatus(LetterStatus.correct), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Set for ${widget.reminderTimeLabel} — see you then.',
                      style: AppType.nunito(
                          fontSize: 13.5, color: AppPalette.ink)),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.present.withValues(alpha: 0.14),
                  ),
                  child: const Icon(Icons.bedtime_outlined,
                      color: AppPalette.present, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A gentle daily nudge?',
                          style: AppType.fredoka(
                              fontSize: 15, color: AppPalette.ink)),
                      const SizedBox(height: 2),
                      Text("We'll say when a new word is ready — nothing more.",
                          style: AppType.nunito(
                              fontSize: 12.5,
                              color: AppPalette.muted,
                              height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _turnOnButton(),
              ],
            ),
    );
  }

  Widget _turnOnButton() {
    return OutlinedButton(
      onPressed: _busy ? null : _turnOn,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: AppPalette.present.withValues(alpha: 0.6)),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: _busy
          ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Text('Turn on',
              style: AppType.fredoka(
                  fontSize: 14, color: AppPalette.present)),
    );
  }

  Widget _journeyLine() {
    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        style: AppType.nunito(fontSize: 13, color: AppPalette.muted, height: 1.4),
        children: [
          const TextSpan(text: 'Next: '),
          TextSpan(
            text: '${GameController.firstStepsLevels} quick warm-up words',
            style: AppType.nunito(
              fontSize: 13,
              color: AppPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: ", then today's Daily."),
        ],
      ),
    );
  }

  Widget _primaryCta() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF57A99B), Color(0xFF4A9184)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9B8E).withValues(alpha: 0.5),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onContinue,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text('Start warm-up',
                  style: AppType.fredoka(
                      fontSize: 17, color: const Color(0xFF0E1513))),
            ),
          ),
        ),
      ),
    );
  }
}
