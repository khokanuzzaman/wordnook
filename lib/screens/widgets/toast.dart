import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../logic/coin_rules.dart';
import '../../logic/tips.dart';
import '../../state/game_controller.dart';
import '../../theme/app_theme.dart';

/// The four warm toast variants (handoff-toast §C).
enum ToastKind { hint, reward, validation, unavailable, tip }

/// Win-praise words emitted by the controller on a solve. Kept in sync with
/// GameController._winMessage. Used both to classify a win as a reward and to
/// suppress the (redundant) daily win toast — see [ToastHost].
const List<String> kWinPraise = [
  'Genius!',
  'Magnificent!',
  'Impressive!',
  'Splendid!',
  'Great!',
  'Phew!',
];

/// Pure mapping from a controller message to its toast kind. Presentation only —
/// the controller keeps producing the same strings.
ToastKind classifyToast(String m) {
  if (m.startsWith('Hint: position')) return ToastKind.hint;
  if (TipRules.isTip(m)) return ToastKind.tip;
  if (m.startsWith('No ad available')) return ToastKind.unavailable;
  if ((m.startsWith('+') && m.contains('coins')) ||
      m.contains('granted') ||
      m.contains('restored')) {
    return ToastKind.reward;
  }
  if (kWinPraise.any(m.startsWith)) return ToastKind.reward; // win praise
  // Everything else is a gentle validation notice: "Not in word list",
  // "Not enough letters", "Hard mode: …", "Need N coins …",
  // "Every letter is already revealed", "Out of guesses — the word was …".
  return ToastKind.validation;
}

/// True for a solve-praise message (used to suppress the daily win toast).
bool isWinPraise(String m) => kWinPraise.any(m.startsWith);

/// Fixed feedback zone just above the keyboard. Listens to the controller's
/// transient message, styles it as the matching warm toast, auto-dismisses
/// after ~2.2s, and replaces the current toast when a new message arrives.
class ToastHost extends StatefulWidget {
  final GameController controller;
  const ToastHost({super.key, required this.controller});

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> with TickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 340));
  late final AnimationController _life =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  String? _text;
  ToastKind _kind = ToastKind.validation;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
    _life.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_exiting) _beginExit();
    });
    _in.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && _exiting && mounted) {
        setState(() {
          _text = null;
          _exiting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    _in.dispose();
    _life.dispose();
    super.dispose();
  }

  void _onControllerChange() {
    final msg = widget.controller.message;
    if (msg == null) return;
    widget.controller.clearMessage(); // silent: does not notify
    // The confetti + Stats result screen own the daily win — don't also toast
    // its praise. Journey (no result screen) keeps the praise toast.
    if (widget.controller.mode == GameMode.daily && isWinPraise(msg)) return;
    _present(msg, classifyToast(msg));
  }

  void _present(String text, ToastKind kind) {
    // Tips teach — give them time to be read.
    _life.duration = Duration(milliseconds: kind == ToastKind.tip ? 4000 : 2200);
    setState(() {
      _text = text;
      _kind = kind;
      _exiting = false;
    });
    _in.forward(from: 0);
    _life.forward(from: 0);
  }

  void _beginExit() {
    if (!mounted || _text == null) return;
    _exiting = true;
    _in.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (_text == null) return const SizedBox(width: double.infinity);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _life]),
        builder: (_, __) => CozyToast(
          kind: _kind,
          text: _text!,
          entrance: _in.value,
          life: _life.value,
          reduce: reduce,
        ),
      ),
    );
  }
}

/// The warm toast card. Purely presentational: given the [entrance] (0→1) and
/// [life] (0→1) drivers it computes its own fade / scale / flourish so the host
/// only has to run two one-shot controllers.
class CozyToast extends StatelessWidget {
  final ToastKind kind;
  final String text;
  final double entrance;
  final double life;
  final bool reduce;
  const CozyToast({
    super.key,
    required this.kind,
    required this.text,
    this.entrance = 1,
    this.life = 0,
    this.reduce = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = _ToastStyle.of(kind);
    final opacity = entrance.clamp(0.0, 1.0);
    final scale = reduce ? 1.0 : 0.97 + 0.03 * entrance;
    // Enters with a gentle 12px drop into place (paint-only, no layout thrash).
    final dropY = reduce ? 0.0 : -(1 - entrance) * 12;
    // Validation gives a single soft shake (±3px, damped) on entry.
    final shakeX = (reduce || kind != ToastKind.validation)
        ? 0.0
        : math.sin(entrance * math.pi * 3) * (1 - entrance) * 3;
    final remaining = (1 - life).clamp(0.0, 1.0);

    final card = Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.top, s.bottom],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: s.border),
        boxShadow: const [
          BoxShadow(
              color: AppPalette.toastShadow,
              blurRadius: 30,
              offset: Offset(0, 14),
              spreadRadius: -12),
        ],
      ),
      child: Row(
        children: [
          _IconWell(kind: kind, style: s, entrance: entrance, life: life, reduce: reduce),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.nunito(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: s.text),
            ),
          ),
          if (s.badge != null) ...[
            const SizedBox(width: 10),
            _Badge(
              label: s.badge!,
              fill: s.badgeFill!,
              border: s.badgeBorder!,
              text: s.badgeText!,
            ),
          ],
        ],
      ),
    );

    // Progress hairline pinned to the card bottom (doubles as dismiss timer).
    final Widget content = reduce
        ? card
        : Stack(
            children: [
              card,
              Positioned(
                left: 14,
                right: 14,
                bottom: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    height: 2,
                    color: AppPalette.toastTrack,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: remaining,
                        child: Container(
                          color: s.accent.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(shakeX, dropY),
        child: Transform.scale(scale: scale, child: content),
      ),
    );
  }
}

/// 30×30 leading icon well with the per-type drawn mark (Material vector icons /
/// the reused coin gradient — never emoji).
class _IconWell extends StatelessWidget {
  final ToastKind kind;
  final _ToastStyle style;
  final double entrance;
  final double life;
  final bool reduce;
  const _IconWell({
    required this.kind,
    required this.style,
    required this.entrance,
    required this.life,
    required this.reduce,
  });

  @override
  Widget build(BuildContext context) {
    Widget mark;
    switch (kind) {
      case ToastKind.hint:
      case ToastKind.tip:
        mark = const Icon(Icons.lightbulb, size: 17, color: AppPalette.present);
        break;
      case ToastKind.reward:
        // Reward coin pops in on entry; reuses the top-bar coin gradient token.
        final pop = reduce ? 1.0 : 1 + 0.28 * math.sin(entrance * math.pi);
        mark = Transform.scale(
          scale: pop,
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [AppPalette.coinTop, AppPalette.coinBottom],
              ),
            ),
          ),
        );
        break;
      case ToastKind.validation:
        mark = const Icon(Icons.info_outline, size: 17, color: AppPalette.present);
        break;
      case ToastKind.unavailable:
        mark = const Icon(Icons.schedule, size: 17, color: AppPalette.muted);
        break;
    }

    // Hint bulb: a soft glow that breathes over the toast's life.
    List<BoxShadow>? glow;
    if (kind == ToastKind.hint) {
      final b = reduce ? 0.5 : 0.35 + 0.35 * (0.5 + 0.5 * math.sin(life * math.pi * 2));
      glow = [
        BoxShadow(
            color: AppPalette.present.withValues(alpha: 0.35 * b),
            blurRadius: 10,
            spreadRadius: 0),
      ];
    }

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.well,
        borderRadius: BorderRadius.circular(9),
        boxShadow: glow,
      ),
      child: mark,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color fill;
  final Color border;
  final Color text;
  const _Badge(
      {required this.label,
      required this.fill,
      required this.border,
      required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: AppType.fredoka(fontSize: 12, color: text)),
    );
  }
}

/// Resolved per-type colours + optional badge, assembled from AppPalette tokens.
class _ToastStyle {
  final Color top, bottom, border, well, accent, text;
  final String? badge;
  final Color? badgeFill, badgeBorder, badgeText;
  const _ToastStyle({
    required this.top,
    required this.bottom,
    required this.border,
    required this.well,
    required this.accent,
    required this.text,
    this.badge,
    this.badgeFill,
    this.badgeBorder,
    this.badgeText,
  });

  static _ToastStyle of(ToastKind kind) {
    switch (kind) {
      case ToastKind.hint:
        return const _ToastStyle(
          top: AppPalette.toastHintTop,
          bottom: AppPalette.toastHintBottom,
          border: AppPalette.toastHintBorder,
          well: AppPalette.toastHintWell,
          accent: AppPalette.present,
          text: AppPalette.ink,
          badge: '-${CoinRules.hintCost}', // REAL cost (15), not the mockup's 5
          badgeFill: AppPalette.toastHintBadgeFill,
          badgeBorder: AppPalette.toastHintBadgeBorder,
          badgeText: AppPalette.coinsAmber,
        );
      case ToastKind.tip:
        // Same warm amber card as a hint, without the coin-cost badge.
        return const _ToastStyle(
          top: AppPalette.toastHintTop,
          bottom: AppPalette.toastHintBottom,
          border: AppPalette.toastHintBorder,
          well: AppPalette.toastHintWell,
          accent: AppPalette.present,
          text: AppPalette.ink,
        );
      case ToastKind.reward:
        return const _ToastStyle(
          top: AppPalette.toastRewardTop,
          bottom: AppPalette.toastRewardBottom,
          border: AppPalette.toastRewardBorder,
          well: AppPalette.toastRewardWell,
          accent: AppPalette.dailyDot,
          text: AppPalette.ink,
          badge: 'Nice',
          badgeFill: AppPalette.toastRewardBadgeFill,
          badgeBorder: AppPalette.toastRewardBadgeBorder,
          badgeText: AppPalette.toastRewardBadgeText,
        );
      case ToastKind.validation:
        return const _ToastStyle(
          top: AppPalette.toastValidTop,
          bottom: AppPalette.toastValidBottom,
          border: AppPalette.toastValidBorder,
          well: AppPalette.toastValidWell,
          accent: AppPalette.toastValidAccent,
          text: AppPalette.ink,
        );
      case ToastKind.unavailable:
        return const _ToastStyle(
          top: AppPalette.toastUnavailTop,
          bottom: AppPalette.toastUnavailBottom,
          border: AppPalette.toastUnavailBorder,
          well: AppPalette.toastUnavailWell,
          accent: AppPalette.muted,
          text: AppPalette.chipText,
        );
    }
  }
}
